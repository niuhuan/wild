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

pub(crate) static RESTART_FLAG: Lazy<Mutex<bool>> = Lazy::new(|| Mutex::new(false));

async fn need_restart() -> bool {
    *RESTART_FLAG.lock().await
}

pub async fn reset_fail_downloads() -> Result<()> {
    novel_download_picture::Entity::reset_fail_downloads().await?;
    novel_download_chapter::Entity::reset_fail_downloads().await?;
    novel_download_volume::Entity::reset_fail_downloads().await?;
    novel_download::Entity::reset_fail_downloads().await?;
    // need restart
    *RESTART_FLAG.lock().await = true;
    info!("Reset fail downloads");
    Ok(())
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
            if need_restart().await {
                warn!(novel_id = %novel.novel_id, "Download interrupted after novel status check");
                break;
            }

            info!(
                novel_id = %novel.novel_id,
                novel_name = %novel.novel_name,
                "Processing novel"
            );
            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&novel.novel_id);

            if novel.cover_download_status == 0 {
                match CLIENT.download_image(&novel.cover_url).await {
                    Ok(cover_content) => {
                        let cover_file_path = novel_dir.join("cover");
                        match tokio::fs::write(&cover_file_path, cover_content).await {
                            Ok(_) => {
                                debug!(novel_id = %novel.novel_id, "Successfully downloaded cover");
                                novel_download::Entity::update_cover_download_status(
                                    &novel.novel_id,
                                    1,
                                )
                                .await?;
                            }
                            Err(e) => {
                                error!(novel_id = %novel.novel_id, error = %e, "Failed to write cover file");
                                novel_download::Entity::update_cover_download_status(
                                    &novel.novel_id,
                                    2,
                                )
                                .await?;
                            }
                        }
                    }
                    Err(e) => {
                        error!(novel_id = %novel.novel_id, error = %e, "Failed to download cover");
                        novel_download::Entity::update_cover_download_status(&novel.novel_id, 2)
                            .await?;
                    }
                }
            }

            if need_restart().await {
                debug!("Download manager restarting after deletion check");
                continue;
            }

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
                                    } else {
                                        // 更新小说下载章节数
                                        if let Err(e) =
                                            novel_download::Entity::add_one_download_chapter_count(
                                                &novel.novel_id,
                                            )
                                            .await
                                        {
                                            error!(
                                                novel_id = %novel.novel_id,
                                                chapter_id = %chapter.id,
                                                error = %e,
                                                "Failed to update novel download chapter count"
                                            );
                                        }
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

            while let Some(picture) =
                novel_download_picture::Entity::find_incomplete_by_novel(&novel.novel_id).await?
            {
                info!(
                    novel_id = %novel.novel_id,
                    picture_id = %picture.url,
                    "Processing picture"
                );

                if need_restart().await {
                    warn!(picture_id = %picture.url, "Download interrupted after picture processing");
                    break;
                }

                match CLIENT.download_image(&picture.url).await {
                    Ok(content) => {
                        let picture_file_path =
                            novel_dir.join(format!("picture_{}", picture.url_md5));
                        match tokio::fs::write(&picture_file_path, content).await {
                            Ok(_) => {
                                debug!(novel_id = %novel.novel_id, "Successfully downloaded picture");
                                novel_download_picture::Entity::update_download_status(
                                    &picture.aid,
                                    &picture.volume_id,
                                    &picture.chapter_id,
                                    picture.picture_idx,
                                    1,
                                )
                                .await?;
                            }
                            Err(e) => {
                                error!(picture_id = %picture.url, error = %e, "Failed to write picture file");
                                novel_download_picture::Entity::update_download_status(
                                    &picture.aid,
                                    &picture.volume_id,
                                    &picture.chapter_id,
                                    picture.picture_idx,
                                    2,
                                )
                                .await?;
                            }
                        }
                    }
                    Err(e) => {
                        error!(picture_id = %picture.url, error = %e, "Failed to download picture");
                        novel_download_picture::Entity::update_download_status(
                            &picture.aid,
                            &picture.volume_id,
                            &picture.chapter_id,
                            picture.picture_idx,
                            2,
                        )
                        .await?;
                    }
                }
            }

            if need_restart().await {
                warn!(novel_id = %novel.novel_id, "Download interrupted after novel status check");
                break;
            }

            // 总结
            // Check novel status
            let volumes = novel_download_volume::Entity::find_by_novel_id(&novel.novel_id).await?;
            let has_failed = volumes.iter().any(|volume| volume.download_status == 2);
            if has_failed {
                info!(
                    novel_id = %novel.novel_id,
                    "Novel has failed volumes"
                );
                let _ = novel_download::Entity::update_status(&novel.novel_id, 2).await;
            }
            let all_success = volumes.iter().all(|volume| volume.download_status == 1);
            if !all_success {
                continue;
            }
            let all_pictures =
                novel_download_picture::Entity::find_by_novel_id(&novel.novel_id).await?;
            let has_failed = all_pictures
                .iter()
                .any(|picture| picture.download_status == 2);
            if has_failed {
                let _ = novel_download::Entity::update_status(&novel.novel_id, 2).await;
                continue;
            }
            let all_success = all_pictures
                .iter()
                .all(|picture| picture.download_status == 1);
            if !all_success {
                continue;
            }
            let all_chapters = novel_download_chapter::Entity::find_by_novel_id(&novel.novel_id).await?;
            let has_failed = all_chapters.iter().any(|chapter| chapter.download_status == 2);
            if has_failed {
                let _ = novel_download::Entity::update_status(&novel.novel_id, 2).await;
                continue;
            }
            let all_success = all_chapters.iter().all(|chapter| chapter.download_status == 1);
            if !all_success {
                continue;
            }
            let success_chapter_count = all_chapters.iter().filter(|chapter| chapter.download_status == 1).count();
            let _ = novel_download::Entity::update_download_chapter_count(&novel.novel_id, success_chapter_count.try_into().unwrap()).await;
            let _ = novel_download::Entity::update_status(&novel.novel_id, 1).await;
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
