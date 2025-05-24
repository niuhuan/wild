use sea_orm::{prelude::*, sea_query::{Index, SqliteQueryBuilder}, Order, QueryOrder, QuerySelect, Schema, Set, Statement};
use serde::{Deserialize, Serialize};
use std::ops::Deref;

use super::get_connect;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "novel_download_volume")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    pub novel_id: String,
    pub volume_idx: i32,
    pub title: String,
    pub download_status: i32,
    pub create_time: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {
    pub async fn find_by_id(id: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::Id.eq(id))
            .one(get_connect().await.deref())
            .await
    }

    pub async fn find_by_novel_id(novel_id: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::NovelId.eq(novel_id))
            .order_by(Column::VolumeIdx, Order::Asc)
            .all(get_connect().await.deref())
            .await
    }

    pub async fn upsert(
        id: &str,
        novel_id: &str,
        volume_idx: i32,
        title: &str,
        download_status: i32,
    ) -> Result<(), DbErr> {
        let now = chrono::Utc::now().timestamp();
        let model = ActiveModel {
            id: Set(id.to_string()),
            novel_id: Set(novel_id.to_string()),
            volume_idx: Set(volume_idx),
            title: Set(title.to_string()),
            download_status: Set(download_status),
            create_time: Set(now),
        };

        Entity::insert(model)
            .on_conflict(
                sea_orm::sea_query::OnConflict::column(Column::Id)
                    .update_columns([
                        Column::NovelId,
                        Column::VolumeIdx,
                        Column::Title,
                        Column::DownloadStatus,
                    ])
                    .to_owned(),
            )
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn update_download_status(
        id: &str,
        download_status: i32,
    ) -> Result<(), DbErr> {
        let model = ActiveModel {
            id: Set(id.to_string()),
            download_status: Set(download_status),
            ..Default::default()
        };

        Entity::update(model)
            .filter(Column::Id.eq(id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn delete_by_novel_id(novel_id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::NovelId.eq(novel_id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn delete_by_id(id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::Id.eq(id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn delete_all() -> Result<(), DbErr> {
        Entity::delete_many()
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }
}

pub mod migrations {
    use sea_orm_migration::prelude::*;
    use super::Entity;
    use super::Column;

    pub struct M000001CreateTableNovelDownloadVolume;

    impl MigrationName for M000001CreateTableNovelDownloadVolume {
        fn name(&self) -> &str {
            "m000001_create_table_novel_download_volume"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000001CreateTableNovelDownloadVolume {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_table(
                    Table::create()
                        .table(Entity)
                        .if_not_exists()
                        .col(
                            ColumnDef::new(Column::Id)
                                .string()
                                .not_null()
                                .primary_key(),
                        )
                        .col(ColumnDef::new(Column::NovelId).string().not_null())
                        .col(ColumnDef::new(Column::VolumeIdx).integer().not_null())
                        .col(ColumnDef::new(Column::Title).string().not_null())
                        .col(ColumnDef::new(Column::DownloadStatus).integer().not_null())
                        .col(ColumnDef::new(Column::CreateTime).big_integer().not_null())
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_table(Table::drop().table(Entity).to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000002IdxNovelIdNovelDownloadVolume;

    impl MigrationName for M000002IdxNovelIdNovelDownloadVolume {
        fn name(&self) -> &str {
            "m000002_idx_novel_id_novel_download_volume"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000002IdxNovelIdNovelDownloadVolume {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_volume_novel_id")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::NovelId)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_volume_novel_id").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000003IdxNovelIdVolumeIdxNovelDownloadVolume;

    impl MigrationName for M000003IdxNovelIdVolumeIdxNovelDownloadVolume {
        fn name(&self) -> &str {
            "m000003_idx_novel_id_volume_idx_novel_download_volume"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000003IdxNovelIdVolumeIdxNovelDownloadVolume {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_volume_novel_id_volume_idx")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::NovelId)
                        .col(Column::VolumeIdx)
                        .unique()
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_volume_novel_id_volume_idx").to_owned())
                .await?;

            Ok(())
        }
    }
} 