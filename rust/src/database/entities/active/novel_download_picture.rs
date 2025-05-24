use sea_orm::{prelude::*, sea_query::{Index, SqliteQueryBuilder}, Order, QueryOrder, QuerySelect, Schema, Set, Statement};
use serde::{Deserialize, Serialize};
use std::ops::Deref;

use super::get_connect;

/// 小说章节图片下载表
/// 
/// 字段说明：
/// - aid: 小说ID，关联 novel_download 表的 novel_id
/// - volume_id: 卷ID，关联 novel_download_volume 表的 id
/// - chapter_id: 章节ID，关联 novel_download_chapter 表的 id
/// - picture_idx: 图片序号，用于排序
/// - url: 图片URL
/// - url_md5: 图片URL的MD5值，用于去重和缓存
/// - download_status: 下载状态（0: 未开始, 1: 下载中, 2: 已完成, 3: 错误）
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "novel_download_picture")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub aid: String,
    #[sea_orm(primary_key)]
    pub volume_id: String,
    #[sea_orm(primary_key)]
    pub chapter_id: String,
    #[sea_orm(primary_key)]
    pub picture_idx: i32,
    pub url: String,
    pub url_md5: String,
    pub download_status: i32,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {

    pub async fn find_by_url(url: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::Url.eq(url))
            .limit(1)
            .one(get_connect().await.deref())
            .await
    }

    pub async fn find_incomplete_by_novel(novel_id: &str) -> Result<Option<Model>, DbErr> {
        Entity::find()
            .filter(Column::Aid.eq(novel_id))
            .filter(Column::DownloadStatus.eq(0))
            .order_by(Column::PictureIdx, Order::Asc)
            .limit(1)
            .one(get_connect().await.deref())
            .await
    }

    pub async fn delete_by_novel_id(conn: &impl ConnectionTrait, novel_id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::Aid.eq(novel_id))
            .exec(conn)
            .await?;
        Ok(())
    }

    pub async fn find_by_novel_id(novel_id: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::Aid.eq(novel_id))
            .all(get_connect().await.deref())
            .await
    }

    /// 根据章节ID查找所有图片，按图片序号排序
    pub async fn find_by_chapter_id(chapter_id: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::ChapterId.eq(chapter_id))
            .order_by(Column::PictureIdx, Order::Asc)
            .all(get_connect().await.deref())
            .await
    }

    /// 根据小说ID查找所有图片
    pub async fn find_by_aid(aid: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::Aid.eq(aid))
            .all(get_connect().await.deref())
            .await
    }

    /// 根据卷ID查找所有图片
    pub async fn find_by_volume_id(volume_id: &str) -> Result<Vec<Model>, DbErr> {
        Entity::find()
            .filter(Column::VolumeId.eq(volume_id))
            .all(get_connect().await.deref())
            .await
    }

    /// 插入或更新图片信息
    pub async fn upsert(
        aid: &str,
        volume_id: &str,
        chapter_id: &str,
        picture_idx: i32,
        url: &str,
        url_md5: &str,
        download_status: i32,
    ) -> Result<(), DbErr> {
        let model = ActiveModel {
            aid: Set(aid.to_string()),
            volume_id: Set(volume_id.to_string()),
            chapter_id: Set(chapter_id.to_string()),
            picture_idx: Set(picture_idx),
            url: Set(url.to_string()),
            url_md5: Set(url_md5.to_string()),
            download_status: Set(download_status),
        };

        Entity::insert(model)
            .on_conflict(
                sea_orm::sea_query::OnConflict::columns([
                    Column::Aid,
                    Column::VolumeId,
                    Column::ChapterId,
                    Column::PictureIdx,
                ])
                .update_columns([
                    Column::Url,
                    Column::UrlMd5,
                    Column::DownloadStatus,
                ])
                .to_owned(),
            )
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 更新图片下载状态
    pub async fn update_download_status(
        aid: &str,
        volume_id: &str,
        chapter_id: &str,
        picture_idx: i32,
        download_status: i32,
    ) -> Result<(), DbErr> {
        let model = ActiveModel {
            aid: Set(aid.to_string()),
            volume_id: Set(volume_id.to_string()),
            chapter_id: Set(chapter_id.to_string()),
            picture_idx: Set(picture_idx),
            url_md5: Set(String::new()), // 保持原有值
            download_status: Set(download_status),
            ..Default::default()
        };

        Entity::update(model)
            .filter(Column::Aid.eq(aid))
            .filter(Column::VolumeId.eq(volume_id))
            .filter(Column::ChapterId.eq(chapter_id))
            .filter(Column::PictureIdx.eq(picture_idx))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 根据小说ID删除所有图片
    pub async fn delete_by_aid(aid: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::Aid.eq(aid))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 根据卷ID删除所有图片
    pub async fn delete_by_volume_id(volume_id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::VolumeId.eq(volume_id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 根据章节ID删除所有图片
    pub async fn delete_by_chapter_id(chapter_id: &str) -> Result<(), DbErr> {
        Entity::delete_many()
            .filter(Column::ChapterId.eq(chapter_id))
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }

    /// 删除所有图片
    pub async fn delete_all() -> Result<(), DbErr> {
        Entity::delete_many()
            .exec(get_connect().await.deref())
            .await?;

        Ok(())
    }
}

pub mod migrations {
    use sea_orm::EntityName;
    use sea_orm::IdenStatic;
    use sea_orm::Schema;
    use sea_orm_migration::prelude::*;
    use super::Entity;
    use super::Column;

    pub struct M000001CreateTableNovelDownloadPicture;

    impl MigrationName for M000001CreateTableNovelDownloadPicture {
        fn name(&self) -> &str {
            "m000001_create_table_novel_download_picture"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000001CreateTableNovelDownloadPicture {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_table(
                    Table::create()
                        .table(Entity)
                        .if_not_exists()
                        .col(ColumnDef::new(Column::Aid).string().not_null())
                        .col(ColumnDef::new(Column::VolumeId).string().not_null())
                        .col(ColumnDef::new(Column::ChapterId).string().not_null())
                        .col(ColumnDef::new(Column::PictureIdx).integer().not_null())
                        .col(ColumnDef::new(Column::Url).string().not_null())
                        .col(ColumnDef::new(Column::UrlMd5).string().not_null())
                        .col(ColumnDef::new(Column::DownloadStatus).integer().not_null())
                        .primary_key(
                            &mut Index::create()
                                .name("pk_novel_download_picture")
                                .if_not_exists()
                                .col(Column::Aid)
                                .col(Column::VolumeId)
                                .col(Column::ChapterId)
                                .col(Column::PictureIdx)
                                .to_owned(),
                        )
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

    pub struct M000002IdxAidNovelDownloadPicture;

    impl MigrationName for M000002IdxAidNovelDownloadPicture {
        fn name(&self) -> &str {
            "m000002_idx_aid_novel_download_picture"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000002IdxAidNovelDownloadPicture {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_picture_url")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::Url)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_picture_url").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000003IdxAidChapterIdNovelDownloadPicture;

    impl MigrationName for M000003IdxAidChapterIdNovelDownloadPicture {
        fn name(&self) -> &str {
            "m000003_idx_aid_chapter_id_novel_download_picture"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000003IdxAidChapterIdNovelDownloadPicture {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_picture_chapter_id")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::ChapterId)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_picture_chapter_id").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000004IdxAidChapterIdPictureIdxNovelDownloadPicture;

    impl MigrationName for M000004IdxAidChapterIdPictureIdxNovelDownloadPicture {
        fn name(&self) -> &str {
            "m000004_idx_aid_chapter_id_picture_idx_novel_download_picture"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000004IdxAidChapterIdPictureIdxNovelDownloadPicture {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_picture_chapter_id_picture_idx")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::ChapterId)
                        .col(Column::PictureIdx)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            manager
                .drop_index(Index::drop().name("idx_novel_download_picture_chapter_id_picture_idx").to_owned())
                .await?;

            Ok(())
        }
    }

    pub struct M000005AddUrlMd5NovelDownloadPicture;

    impl MigrationName for M000005AddUrlMd5NovelDownloadPicture {
        fn name(&self) -> &str {
            "m000005_add_url_md5_novel_download_picture"
        }
    }

    #[async_trait::async_trait]
    impl MigrationTrait for M000005AddUrlMd5NovelDownloadPicture {
        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            // 添加 url_md5 列
            let db = manager.get_connection();
            let backend = db.get_database_backend();
            let schema = Schema::new(backend);
            if !manager
                .has_column(
                    super::Entity.table_name(),
                    super::Column::UrlMd5.as_str(),
                )
                .await?
            {
                manager
                    .alter_table(
                        Table::alter()
                            .table(Entity)
                            .add_column(ColumnDef::new(Column::UrlMd5).string().not_null().default(""))
                            .to_owned(),
                    )
                    .await?;
            }

            // 为 url_md5 创建索引
            manager
                .create_index(
                    Index::create()
                        .name("idx_novel_download_picture_url_md5")
                        .table(Entity)
                        .if_not_exists()
                        .col(Column::UrlMd5)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }

        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
            // 删除 url_md5 索引
            manager
                .drop_index(Index::drop().name("idx_novel_download_picture_url_md5").to_owned())
                .await?;

            // 删除 url_md5 列
            manager
                .alter_table(
                    Table::alter()
                        .table(Entity)
                        .drop_column(Column::UrlMd5)
                        .to_owned(),
                )
                .await?;

            Ok(())
        }
    }
} 