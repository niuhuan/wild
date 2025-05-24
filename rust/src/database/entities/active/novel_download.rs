use sea_orm::{
    prelude::*,
    sea_query::{Expr, Index, SqliteQueryBuilder},
    ColumnTrait, DatabaseConnection, EntityTrait, Order, QueryOrder, QuerySelect, Schema, Set,
    Statement,
};
use serde::{Deserialize, Serialize};
use std::ops::Deref;

use super::get_connect;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "novel_download")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub novel_id: String,
    pub novel_name: String,
    pub download_status: i32,
    pub cover_url: String,
    pub cover_download_status: i32,
    pub author: String,
    pub tags: String,
    pub choose_chapter_count: i32,
    pub download_chapter_count: i32,
    pub create_time: i64,
    pub download_time: i64,
    pub introduce: String,
    pub trending: String,
    pub is_animated: bool,
    pub fin_update: String,
    pub status: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {
    pub async fn add_one_download_chapter_count(novel_id: &str) -> Result<(), DbErr> {
        Entity::update_many()
            .col_expr(Column::DownloadChapterCount, Expr::col(Column::DownloadChapterCount).add(1))
            .filter(Column::NovelId.eq(novel_id))
            .exec(get_connect().await.deref())
            .await?;
        Ok(())
    }

    pub async fn find_by_image_url(img_url: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::CoverUrl.eq(img_url))
            .limit(1)
            .one(get_connect().await.deref())
            .await
    }

    pub async fn find_by_novel_id(novel_id: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::NovelId.eq(novel_id))
            .one(get_connect().await.deref())
            .await
    }

    pub async fn upsert(
        novel_id: &str,
        novel_name: &str,
        download_status: i32,
        cover_url: &str,
        cover_download_status: i32,
        author: &str,
        tags: &str,
        choose_chapter_count: i32,
        download_chapter_count: i32,
        introduce: &str,
        trending: &str,
        is_animated: bool,
        fin_update: &str,
        status: &str,
    ) -> Result<(), DbErr> {
        let now = chrono::Utc::now().timestamp();
        let model = ActiveModel {
            novel_id: Set(novel_id.to_string()),
            novel_name: Set(novel_name.to_string()),
            download_status: Set(download_status),
            cover_url: Set(cover_url.to_string()),
            cover_download_status: Set(cover_download_status),
            author: Set(author.to_string()),
            tags: Set(tags.to_string()),
            choose_chapter_count: Set(choose_chapter_count),
            download_chapter_count: Set(download_chapter_count),
            create_time: Set(now),
            download_time: Set(now),
            introduce: Set(introduce.to_string()),
            trending: Set(trending.to_string()),
            is_animated: Set(is_animated),
            fin_update: Set(fin_update.to_string()),
            status: Set(status.to_string()),
        };

        Entity::insert(model)
            .on_conflict(
                sea_orm::sea_query::OnConflict::column(Column::NovelId)
                    .update_columns([
                        Column::NovelName,
                        Column::DownloadStatus,
                        Column::CoverUrl,
                        Column::CoverDownloadStatus,
                        Column::Author,
                        Column::Tags,
                        Column::ChooseChapterCount,
                        Column::DownloadChapterCount,
                        Column::DownloadTime,
                        Column::Introduce,
                        Column::Trending,
                        Column::IsAnimated,
                        Column::FinUpdate,
                        Column::Status,
                    ])
                    .to_owned(),
            )
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn update_download_status(novel_id: &str, download_status: i32) -> Result<(), DbErr> {
        let now = chrono::Utc::now().timestamp();
        let model = ActiveModel {
            novel_id: Set(novel_id.to_string()),
            download_status: Set(download_status),
            download_time: Set(now),
            ..Default::default()
        };

        Entity::update(model)
            .filter(Column::NovelId.eq(novel_id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn update_cover_download_status(
        novel_id: &str,
        cover_download_status: i32,
    ) -> Result<(), DbErr> {
        let model = ActiveModel {
            novel_id: Set(novel_id.to_string()),
            cover_download_status: Set(cover_download_status),
            ..Default::default()
        };

        Entity::update(model)
            .filter(Column::NovelId.eq(novel_id))
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

    pub async fn delete_all() -> Result<(), DbErr> {
        Entity::delete_many()
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn find_all_ordered_by_create_time(
        db: &DatabaseConnection,
    ) -> crate::Result<Vec<Model>> {
        Ok(Self::find()
            .order_by_desc(Column::CreateTime)
            .all(db)
            .await?)
    }

    pub async fn find_first_deleting() -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::DownloadStatus.eq(3))
            .one(get_connect().await.deref())
            .await
    }

    pub async fn find_first_not_started() -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::DownloadStatus.eq(0))
            .one(get_connect().await.deref())
            .await
    }

    pub async fn update_status(novel_id: &str, status: i32) -> Result<(), DbErr> {
        Entity::update_many()
            .filter(Column::NovelId.eq(novel_id))
            .set(ActiveModel {
                download_status: Set(status),
                ..Default::default()
            })
            .exec(get_connect().await.deref())
            .await?;
        Ok(())
    }
}

pub mod migrations {
    use super::Column;
    use super::Entity;
    use sea_orm_migration::prelude::*;

    pub struct M000001CreateTableNovelDownload;

    impl MigrationName for M000001CreateTableNovelDownload {
        fn name(&self) -> &str {
            "m000001_create_table_novel_download"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000001CreateTableNovelDownload {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_table(
                    Table::create()
                        .table(Entity)
                        .if_not_exists()
                        .col(
                            ColumnDef::new(Column::NovelId)
                                .string()
                                .not_null()
                                .primary_key(),
                        )
                        .col(ColumnDef::new(Column::NovelName).string().not_null())
                        .col(ColumnDef::new(Column::DownloadStatus).integer().not_null())
                        .col(ColumnDef::new(Column::CoverUrl).string().not_null())
                        .col(
                            ColumnDef::new(Column::CoverDownloadStatus)
                                .integer()
                                .not_null(),
                        )
                        .col(ColumnDef::new(Column::Author).string().not_null())
                        .col(ColumnDef::new(Column::Tags).string().not_null())
                        .col(
                            ColumnDef::new(Column::ChooseChapterCount)
                                .integer()
                                .not_null(),
                        )
                        .col(
                            ColumnDef::new(Column::DownloadChapterCount)
                                .integer()
                                .not_null(),
                        )
                        .col(ColumnDef::new(Column::CreateTime).big_integer().not_null())
                        .col(
                            ColumnDef::new(Column::DownloadTime)
                                .big_integer()
                                .not_null(),
                        )
                        .col(ColumnDef::new(Column::Introduce).string().not_null())
                        .col(ColumnDef::new(Column::Trending).string().not_null())
                        .col(ColumnDef::new(Column::IsAnimated).boolean().not_null())
                        .col(ColumnDef::new(Column::FinUpdate).string().not_null())
                        .col(ColumnDef::new(Column::Status).string().not_null())
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

    pub struct M000002IdxCoverUrlNovelDownload;

    impl MigrationName for M000002IdxCoverUrlNovelDownload {
        fn name(&self) -> &str {
            "m000002_idx_cover_url_novel_download"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000002IdxCoverUrlNovelDownload {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_cover_url")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::CoverUrl)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(
                    Index::drop()
                        .name("idx_novel_download_cover_url")
                        .to_owned(),
                )
                .await?;

            Ok(())
        }
    }

    pub struct M000003IdxCreateTimeNovelDownload;

    impl MigrationName for M000003IdxCreateTimeNovelDownload {
        fn name(&self) -> &str {
            "m000003_idx_create_time_novel_download"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000003IdxCreateTimeNovelDownload {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_create_time")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::CreateTime)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(
                    Index::drop()
                        .name("idx_novel_download_create_time")
                        .to_owned(),
                )
                .await?;

            Ok(())
        }
    }

    pub struct M000004IdxDownloadTimeNovelDownload;

    impl MigrationName for M000004IdxDownloadTimeNovelDownload {
        fn name(&self) -> &str {
            "m000004_idx_download_time_novel_download"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000004IdxDownloadTimeNovelDownload {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_download_time")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::DownloadTime)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(
                    Index::drop()
                        .name("idx_novel_download_download_time")
                        .to_owned(),
                )
                .await?;

            Ok(())
        }
    }

    pub struct M000005IdxCoverUrlNovelDownload;

    impl MigrationName for M000005IdxCoverUrlNovelDownload {
        fn name(&self) -> &str {
            "m000005_idx_cover_url_novel_download"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000005IdxCoverUrlNovelDownload {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_cover_url")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::CoverUrl)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(
                    Index::drop()
                        .name("idx_novel_download_cover_url")
                        .to_owned(),
                )
                .await?;

            Ok(())
        }
    }
}
