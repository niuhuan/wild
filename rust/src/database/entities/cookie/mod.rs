use std::ops::Deref;

use sea_orm::DatabaseConnection;
use sea_orm_migration::{MigrationTrait, MigratorTrait};

use crate::database::COOKIE_DB_CONNECT;

pub mod cookie;


async fn get_connect() -> tokio::sync::MutexGuard<'static, DatabaseConnection> {
    COOKIE_DB_CONNECT.get().unwrap().lock().await
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
        ]
    }
}
