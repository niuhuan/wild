pub use sea_orm_migration::prelude::*;

mod m000001_create_table_cookies;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![Box::new(m000001_create_table_cookies::Migration)]
    }
} 