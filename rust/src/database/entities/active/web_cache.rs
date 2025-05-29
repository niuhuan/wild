use super::get_connect;
use sea_orm::entity::prelude::*;
use sea_orm::*;
use serde::{Deserialize, Serialize};
use std::ops::Deref;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "web_cache")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub cache_key: String,
    pub cache_time: i64,
    pub cache_content: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub mod migrations {
    use sea_orm_migration::prelude::*;

    pub struct Migration;

    impl MigrationName for Migration {
        fn name(&self) -> &str {
            "m000001_create_table_web_cache"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for Migration {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_table(
                    Table::create()
                        .table(super::Entity)
                        .if_not_exists()
                        .col(
                            ColumnDef::new(super::Column::CacheKey)
                                .string()
                                .not_null()
                                .primary_key(),
                        )
                        .col(
                            ColumnDef::new(super::Column::CacheTime)
                                .big_integer()
                                .not_null(),
                        )
                        .col(
                            ColumnDef::new(super::Column::CacheContent)
                                .string()
                                .not_null(),
                        )
                        .to_owned(),
                )
                .await
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_table(Table::drop().table(super::Entity).to_owned())
                .await
        }
    }

    pub struct MigrationIdx;

    impl MigrationName for MigrationIdx {
        fn name(&self) -> &str {
            "m000002_idx_web_cache_time"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for MigrationIdx {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_web_cache_time")
                        .table(super::Entity)
                        .col(super::Column::CacheTime)
                        .if_not_exists()
                        .to_owned(),
                )
                .await
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_web_cache_time").to_owned())
                .await
        }
    }
}

impl Entity {
    pub async fn save_web_cache(key: String, cache_content: String) -> Result<(), DbErr> {
        let db = get_connect().await;
        let model = ActiveModel {
            cache_key: Set(key),
            cache_time: Set(chrono::Utc::now().timestamp()),
            cache_content: Set(cache_content),
        };
        model.insert(db.deref()).await?;
        Ok(())
    }

    pub async fn update_web_cache(key: String, cache_content: String) -> Result<(), DbErr> {
        let db = get_connect().await;
        let model = ActiveModel {
            cache_key: Set(key),
            cache_time: Set(chrono::Utc::now().timestamp()),
            cache_content: Set(cache_content),
        };
        model.update(db.deref()).await?;
        Ok(())
    }

    pub async fn get_web_cache(key: &str) -> Result<Option<Model>, DbErr> {
        let db = get_connect().await;
        Self::find()
            .filter(Column::CacheKey.eq(key))
            .one(db.deref())
            .await
    }

    pub async fn delete_expired_cache(expire_time: i64) -> Result<(), DbErr> {
        let db = get_connect().await;
        Self::delete_many()
            .filter(Column::CacheTime.lt(expire_time))
            .exec(db.deref())
            .await?;
        Ok(())
    }

    pub async fn delete_all() -> Result<(), DbErr> {
        let db = get_connect().await;
        Self::delete_many().exec(db.deref()).await?;
        Ok(())
    }
}
