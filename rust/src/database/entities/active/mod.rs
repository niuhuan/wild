use crate::database::ACTIVE_DB_CONNECT;
use sea_orm::{DatabaseConnection, EntityTrait};
use sea_orm_migration::{MigrationTrait, MigratorTrait};
use std::ops::Deref;

pub mod chapter_cache;
pub mod image_cache;
pub mod novel_download;
pub mod novel_download_chapter;
pub mod novel_download_picture;
pub mod novel_download_volume;
pub mod reading_history;
pub mod search_history;
pub mod sign_log;
pub mod web_cache;

pub use chapter_cache::*;
pub use image_cache::*;
pub use novel_download::*;
pub use novel_download_chapter::*;
pub use novel_download_picture::*;
pub use novel_download_volume::*;
pub use reading_history::*;
pub use search_history::*;
pub use sign_log::*;
pub use web_cache::*;

pub const DOWNLOAD_STATUS_NOT_DOWNLOAD: i32 = 0;
pub const DOWNLOAD_STATUS_SUCCESS: i32 = 1;
pub const DOWNLOAD_STATUS_FAILED: i32 = 2;
pub const DOWNLOAD_STATUS_DELETING: i32 = 3;

async fn get_connect() -> tokio::sync::MutexGuard<'static, DatabaseConnection> {
    ACTIVE_DB_CONNECT.get().unwrap().lock().await
}

pub(crate) async fn remove_download_data(novel_id: &str) -> crate::Result<()> {
    let db = get_connect().await;
    novel_download::Entity::delete_by_id(novel_id).exec(db.deref()).await?;
    novel_download_volume::Entity::delete_by_novel_id(db.deref(), novel_id).await?;
    novel_download_chapter::Entity::delete_by_novel_id(db.deref(),novel_id).await?;
    novel_download_picture::Entity::delete_by_novel_id(db.deref(),novel_id).await?;
    Ok(())
}

pub(crate) async fn migrations() -> crate::Result<()> {
    Migrator::up(get_connect().await.deref(), None).await?;
    Ok(())
}

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(
                reading_history::migrations::m000001_create_table_reading_histories::Migration,
            ),
            Box::new(
                reading_history::migrations::m000002_idx_reading_histories_novel_id::Migration,
            ),
            Box::new(
                image_cache::migrations::m000001_create_table_image_cache::Migration,
            ),
            Box::new(
                image_cache::migrations::m000002_idx_image_cache_url_md5::Migration,
            ),
            Box::new(
                chapter_cache::migrations::m000001_create_table_chapter_cache::Migration,
            ),
            Box::new(
                chapter_cache::migrations::m000002_idx_chapter_cache_aid_cid::Migration,
            ),
            Box::new(
                web_cache::migrations::Migration,
            ),
            Box::new(
                web_cache::migrations::MigrationIdx,
            ),
            Box::new(
                reading_history::migrations::m000003_create_table_reading_histories_volume::Migration,
            ),
            Box::new(
                reading_history::migrations::m000003_create_table_reading_histories_cover_author::Migration,
            ),
            Box::new(
                search_history::migrations::m000001_create_table_search_history::Migration,
            ),
            Box::new(
                search_history::migrations::m000002_idx_search_history_time::Migration,
            ),
            Box::new(
                sign_log::migrations::m000001_create_table_sign_log::Migration,
            ),
            Box::new(
                reading_history::migrations::m000004_add_progress_page::Migration,
            ),
            Box::new(
                novel_download::migrations::M000001CreateTableNovelDownload,
            ),
            Box::new(
                novel_download::migrations::M000002IdxCoverUrlNovelDownload,
            ),
            Box::new(
                novel_download::migrations::M000003IdxCreateTimeNovelDownload,
            ),
            Box::new(
                novel_download::migrations::M000004IdxDownloadTimeNovelDownload,
            ),
            Box::new(
                novel_download_volume::migrations::M000001CreateTableNovelDownloadVolume,
            ),
            Box::new(
                novel_download_volume::migrations::M000002IdxNovelIdNovelDownloadVolume,
            ),
            Box::new(
                novel_download_volume::migrations::M000003IdxNovelIdVolumeIdxNovelDownloadVolume,
            ),
            Box::new(
                novel_download_chapter::migrations::M000001CreateTableNovelDownloadChapter,
            ),
            Box::new(
                novel_download_chapter::migrations::M000002IdxAidNovelDownloadChapter,
            ),
            Box::new(
                novel_download_chapter::migrations::M000003IdxVolumeIdNovelDownloadChapter,
            ),
            Box::new(
                novel_download_chapter::migrations::M000004IdxAidVolumeIdChapterIdxNovelDownloadChapter,
            ),
            Box::new(
                novel_download_picture::migrations::M000001CreateTableNovelDownloadPicture,
            ),
            Box::new(
                novel_download_picture::migrations::M000002IdxAidNovelDownloadPicture,
            ),
            Box::new(
                novel_download_picture::migrations::M000003IdxAidChapterIdNovelDownloadPicture,
            ),
            Box::new(
                novel_download_picture::migrations::M000004IdxAidChapterIdPictureIdxNovelDownloadPicture,
            ),
            Box::new(
                novel_download_picture::migrations::M000005AddUrlMd5NovelDownloadPicture,
            ),
        ]
    }
}
