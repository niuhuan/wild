use sea_orm::{prelude::*, sea_query::{Index, SqliteQueryBuilder}, Order, QueryOrder, QuerySelect, Schema, Set, Statement};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use sea_orm::{EntityTrait, ColumnTrait, DatabaseConnection};

use super::get_connect;

/// 小说章节下载表
/// 
/// 字段说明：
/// - id: 章节ID，主键
/// - title: 章节标题
/// - url: 章节URL
/// - aid: 小说ID，关联 novel_download 表的 novel_id
/// - volume_id: 卷ID，关联 novel_download_volume 表的 id
/// - download_status: 下载状态（0: 未开始, 1: 下载中, 2: 已完成, 3: 错误）
/// - total_picture: 章节总图片数
/// - chapter_idx: 章节序号，用于排序
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "novel_download_chapter")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    pub title: String,
    pub url: String,
    pub aid: String,
    pub volume_id: String,
    pub download_status: i32,
    pub total_picture: i32,
    pub chapter_idx: i32,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {
    /// 根据章节ID查找
    pub async fn find_by_id(id: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::Id.eq(id))
            .one(get_connect().await.deref())
            .await
    }

    /// 根据小说ID查找所有章节，按卷ID和章节序号排序
    pub async fn find_by_aid(aid: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::Aid.eq(aid))
            .order_by(Column::VolumeId, Order::Asc)
            .order_by(Column::ChapterIdx, Order::Asc)
            .all(get_connect().await.deref())
            .await
    }

    /// 根据卷ID查找所有章节，按章节序号排序
    pub async fn find_by_volume_id(volume_id: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::VolumeId.eq(volume_id))
            .order_by(Column::ChapterIdx, Order::Asc)
            .all(get_connect().await.deref())
            .await
    }

    /// 插入或更新章节信息
    pub async fn upsert(
        id: &str,
        title: &str,
        url: &str,
        aid: &str,
        volume_id: &str,
        download_status: i32,
        total_picture: i32,
        chapter_idx: i32,
    ) -> Result<(), DbErr> {
        let model = ActiveModel {
            id: Set(id.to_string()),
            title: Set(title.to_string()),
            url: Set(url.to_string()),
            aid: Set(aid.to_string()),
            volume_id: Set(volume_id.to_string()),
            download_status: Set(download_status),
            total_picture: Set(total_picture),
            chapter_idx: Set(chapter_idx),
        };

        Entity::insert(model)
            .on_conflict(
                sea_orm::sea_query::OnConflict::column(Column::Id)
                    .update_columns([
                        Column::Title,
                        Column::Url,
                        Column::Aid,
                        Column::VolumeId,
                        Column::DownloadStatus,
                        Column::TotalPicture,
                        Column::ChapterIdx,
                    ])
                    .to_owned(),
            )
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 更新章节下载状态
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

    /// 根据小说ID删除所有章节
    pub async fn delete_by_aid(aid: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::Aid.eq(aid))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 根据卷ID删除所有章节
    pub async fn delete_by_volume_id(volume_id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::VolumeId.eq(volume_id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 根据章节ID删除
    pub async fn delete_by_id(id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::Id.eq(id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 删除所有章节
    pub async fn delete_all() -> Result<(), DbErr> {
        Entity::delete_many()
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    pub async fn find_by_novel_id(novel_id: &str) -> crate::Result<Vec<Model>> {
        let db = get_connect().await;
        Ok(Self::find()
            .filter(Column::Aid.eq(novel_id))
            .all(db.deref())
            .await?)
    }
}

pub mod migrations {
    use sea_orm_migration::prelude::*;
    use super::Entity;
    use super::Column;

    pub struct M000001CreateTableNovelDownloadChapter;

    impl MigrationName for M000001CreateTableNovelDownloadChapter {
        fn name(&self) -> &str {
            "m000001_create_table_novel_download_chapter"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000001CreateTableNovelDownloadChapter {
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
                        .col(ColumnDef::new(Column::Title).string().not_null())
                        .col(ColumnDef::new(Column::Url).string().not_null())
                        .col(ColumnDef::new(Column::Aid).string().not_null())
                        .col(ColumnDef::new(Column::VolumeId).string().not_null())
                        .col(ColumnDef::new(Column::DownloadStatus).integer().not_null())
                        .col(ColumnDef::new(Column::TotalPicture).integer().not_null())
                        .col(ColumnDef::new(Column::ChapterIdx).integer().not_null())
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

    pub struct M000002IdxAidNovelDownloadChapter;

    impl MigrationName for M000002IdxAidNovelDownloadChapter {
        fn name(&self) -> &str {
            "m000002_idx_aid_novel_download_chapter"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000002IdxAidNovelDownloadChapter {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_chapter_aid")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::Aid)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_chapter_aid").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000003IdxVolumeIdNovelDownloadChapter;

    impl MigrationName for M000003IdxVolumeIdNovelDownloadChapter {
        fn name(&self) -> &str {
            "m000003_idx_volume_id_novel_download_chapter"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000003IdxVolumeIdNovelDownloadChapter {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_chapter_volume_id")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::VolumeId)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_chapter_volume_id").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000004IdxAidVolumeIdChapterIdxNovelDownloadChapter;

    impl MigrationName for M000004IdxAidVolumeIdChapterIdxNovelDownloadChapter {
        fn name(&self) -> &str {
            "m000004_idx_aid_volume_id_chapter_idx_novel_download_chapter"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000004IdxAidVolumeIdChapterIdxNovelDownloadChapter {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_chapter_aid_volume_id_chapter_idx")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::Aid)
                        .col(Column::VolumeId)
                        .col(Column::ChapterIdx)
                        .unique()
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_chapter_aid_volume_id_chapter_idx").to_owned())
                .await?;

            Ok(())
        }
    }
} 