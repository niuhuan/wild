use crate::database::ACTIVE_DB_CONNECT;
use sea_orm::DatabaseConnection;
use sea_orm_migration::{MigrationTrait, MigratorTrait};
use std::ops::Deref;

pub mod reading_history;

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
        ]
    }
}
