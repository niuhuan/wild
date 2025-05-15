use crate::database::ACTIVE_DB_CONNECT;
use sea_orm::DatabaseConnection;
use sea_orm_migration::{MigrationTrait, MigratorTrait};
use std::ops::Deref;

pub mod chapter_cache;
pub mod image_cache;
pub mod reading_history;
pub mod search_history;
pub mod web_cache;

pub use chapter_cache::*;
pub use image_cache::*;
pub use reading_history::*;
pub use search_history::*;
pub use web_cache::*;

async fn get_connect() -> tokio::sync::MutexGuard<'static, DatabaseConnection> {
    ACTIVE_DB_CONNECT.get().unwrap().lock().await
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
        ]
    }
}
