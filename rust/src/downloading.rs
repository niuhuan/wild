use crate::{
    database::entities::active::{
        self, novel_download, novel_download_chapter, novel_download_picture, novel_download_volume,
    },
    Result, CLIENT, DOWNLOAD_FOLDER,
};
use once_cell::sync::Lazy;
use sea_orm::{EntityTrait, QueryFilter, QueryOrder, QuerySelect};
use std::path::Path;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::task::spawn;
use tracing::{debug, error, info, instrument, warn, Level};

static RESTART_FLAG: Lazy<Mutex<bool>> = Lazy::new(|| Mutex::new(false));

async fn need_restart() -> bool {
    *RESTART_FLAG.lock().await
}

#[instrument(skip_all)]
pub async fn start_downloading() -> Result<()> {
    info!("Starting download manager...");
    spawn(downloading_loop());
    Ok(())
}

#[instrument(skip_all)]
async fn downloading_loop() -> Result<()> {
    info!("Download manager loop started");
    loop {
        // Check for restart flag
        let mut restart_flag = RESTART_FLAG.lock().await;
        if *restart_flag {
            info!("Download manager restarting...");
            *restart_flag = false;
        }
        drop(restart_flag);

        // Step 1: Check for novels to delete
        while let Some(novel) = novel_download::Entity::find_first_deleting().await? {
            info!(
                novel_id = %novel.novel_id,
                novel_name = %novel.novel_name,
                "Found novel to delete"
            );

            // Delete novel folder
            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&novel.novel_id);
            match tokio::fs::remove_dir_all(&novel_dir).await {
                Ok(_) => info!(path = ?novel_dir, "Successfully deleted novel directory"),
                Err(e) => warn!(path = ?novel_dir, error = %e, "Failed to delete novel directory"),
            }

            // Delete from database
            match active::remove_download_data(&novel.novel_id).await {
                Ok(_) => info!(novel_id = %novel.novel_id, "Successfully removed download data"),
                Err(e) => {
                    error!(novel_id = %novel.novel_id, error = %e, "Failed to remove download data")
                }
            }
            continue;
        }

        if need_restart().await {
            debug!("Download manager restarting after deletion check");
            continue;
        }

        // Step 2: Find first incomplete novel
        while let Some(novel) = novel_download::Entity::find_first_not_started().await? {
            info!(
                novel_id = %novel.novel_id,
                novel_name = %novel.novel_name,
                "Processing novel"
            );

            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&novel.novel_id);
            match tokio::fs::create_dir_all(&novel_dir).await {
                Ok(_) => debug!(path = ?novel_dir, "Created/verified novel directory"),
                Err(e) => {
                    error!(path = ?novel_dir, error = %e, "Failed to create novel directory");
                    continue;
                }
            }

            if need_restart().await {
                warn!(novel_id = %novel.novel_id, "Download interrupted");
                break;
            }

            while let Some(volume) =
                novel_download_volume::Entity::find_incomplete_by_novel(&novel.novel_id).await?
            {
                info!(
                    novel_id = %novel.novel_id,
                    volume_id = %volume.id,
                    volume_title = %volume.title,
                    "Processing volume"
                );

                if need_restart().await {
                    warn!(volume_id = %volume.id, "Download interrupted");
                    break;
                }

                if let Some(chapter) = novel_download_chapter::Entity::find_incomplete_by_volume(
                    &novel.novel_id,
                    &volume.id,
                )
                .await?
                {
                    debug!(
                        novel_id = %novel.novel_id,
                        volume_id = %volume.id,
                        chapter_id = %chapter.id,
                        chapter_title = %chapter.title,
                        "Processing chapter"
                    );
                    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await; // 防止下载太快

                    if need_restart().await {
                        warn!(chapter_id = %chapter.id, "Download interrupted");
                        break;
                    }

                    let chapter_file_path = novel_dir.join(format!("chapter_{}", chapter.id));

                    // Download chapter content
                    match CLIENT.c_content(&novel.novel_id, &chapter.id).await {
                        Ok(chapter_content) => {
                            match tokio::fs::write(&chapter_file_path, chapter_content).await {
                                Ok(_) => {
                                    debug!(
                                        novel_id = %novel.novel_id,
                                        chapter_id = %chapter.id,
                                        "Successfully downloaded chapter"
                                    );
                                    if let Err(e) = novel_download_chapter::Entity::update_status(
                                        &novel.novel_id,
                                        &volume.id,
                                        &chapter.id,
                                        1, // Success
                                    )
                                    .await
                                    {
                                        error!(
                                            novel_id = %novel.novel_id,
                                            chapter_id = %chapter.id,
                                            error = %e,
                                            "Failed to update chapter status"
                                        );
                                    }
                                }
                                Err(e) => {
                                    error!(
                                        novel_id = %novel.novel_id,
                                        chapter_id = %chapter.id,
                                        error = %e,
                                        "Failed to write chapter file"
                                    );
                                    if let Err(e) = novel_download_chapter::Entity::update_status(
                                        &novel.novel_id,
                                        &volume.id,
                                        &chapter.id,
                                        2, // Failed
                                    )
                                    .await
                                    {
                                        error!(
                                            novel_id = %novel.novel_id,
                                            chapter_id = %chapter.id,
                                            error = %e,
                                            "Failed to update chapter status"
                                        );
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            error!(
                                novel_id = %novel.novel_id,
                                chapter_id = %chapter.id,
                                error = %e,
                                "Failed to download chapter content"
                            );
                            if let Err(e) = novel_download_chapter::Entity::update_status(
                                &novel.novel_id,
                                &volume.id,
                                &chapter.id,
                                2, // Failed
                            )
                            .await
                            {
                                error!(
                                    novel_id = %novel.novel_id,
                                    chapter_id = %chapter.id,
                                    error = %e,
                                    "Failed to update chapter status"
                                );
                            }
                        }
                    }
                }

                if need_restart().await {
                    warn!(volume_id = %volume.id, "Download interrupted after chapter processing");
                    break;
                }

                let chapters = novel_download_chapter::Entity::find_incomplete_by_volume(
                    &novel.novel_id,
                    &volume.id,
                )
                .await?;

                let has_fail = chapters.iter().any(|chapter| chapter.download_status == 2);
                if has_fail {
                    info!(
                        novel_id = %novel.novel_id,
                        volume_id = %volume.id,
                        "Volume has failed chapters"
                    );
                    if let Err(e) = novel_download_volume::Entity::update_status(
                        &novel.novel_id,
                        &volume.id,
                        2, // Failed
                    )
                    .await
                    {
                        error!(
                            novel_id = %novel.novel_id,
                            volume_id = %volume.id,
                            error = %e,
                            "Failed to update volume status"
                        );
                    }
                } else {
                    let all_success = chapters.iter().all(|chapter| chapter.download_status == 1);
                    if all_success {
                        info!(
                            novel_id = %novel.novel_id,
                            volume_id = %volume.id,
                            "Volume completed successfully"
                        );
                        if let Err(e) = novel_download_volume::Entity::update_status(
                            &novel.novel_id,
                            &volume.id,
                            1, // Success
                        )
                        .await
                        {
                            error!(
                                novel_id = %novel.novel_id,
                                volume_id = %volume.id,
                                error = %e,
                                "Failed to update volume status"
                            );
                        }
                    }
                }
            }

            if need_restart().await {
                warn!(novel_id = %novel.novel_id, "Download interrupted after volume processing");
                break;
            }

            // Check novel status
            let volumes = novel_download_volume::Entity::find_by_novel_id(&novel.novel_id).await?;
            let has_failed = volumes.iter().any(|volume| volume.download_status == 2);
            if has_failed {
                info!(
                    novel_id = %novel.novel_id,
                    "Novel has failed volumes"
                );
                if let Err(e) = novel_download::Entity::update_status(&novel.novel_id, 2).await {
                    error!(
                        novel_id = %novel.novel_id,
                        error = %e,
                        "Failed to update novel status"
                    );
                }
            } else {
                let all_success = volumes.iter().all(|volume| volume.download_status == 1);
                if all_success {
                    let all_pictures =
                        novel_download_picture::Entity::find_by_novel_id(&novel.novel_id).await?;
                    let all_success = all_pictures
                        .iter()
                        .all(|picture| picture.download_status == 1);
                    if all_success {
                        info!(
                            novel_id = %novel.novel_id,
                            "Novel completed successfully"
                        );
                        if let Err(e) =
                            novel_download::Entity::update_status(&novel.novel_id, 1).await
                        {
                            error!(
                                novel_id = %novel.novel_id,
                                error = %e,
                                "Failed to update novel status"
                            );
                        }
                    }
                }
            }

            if need_restart().await {
                warn!(novel_id = %novel.novel_id, "Download interrupted after novel status check");
                break;
            }
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
