use crate::database;
use sea_orm::{prelude::*, IntoActiveModel};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::ops::Deref;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "chapter_cache")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub aid: String,
    #[sea_orm(primary_key, auto_increment = false)]
    pub cid: String,
    pub content: String,
    pub download_time: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

// 章节下载锁
lazy_static::lazy_static! {
    static ref CHAPTER_LOCKS: Arc<Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

pub(super) mod migrations {
    pub(crate) mod m000001_create_table_chapter_cache {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000001_create_table_chapter_cache"
            }
        }

        #[async_trait::async_trait]
        impl MigrationTrait for Migration {
            async fn up(
                &self,
                manager: &SchemaManager,
            ) -> std::result::Result<(), sea_orm_migration::DbErr> {
                let db = manager.get_connection();
                let backend = db.get_database_backend();
                let schema = Schema::new(backend);
                manager
                    .create_table(
                        schema
                            .create_table_from_entity(super::super::Entity)
                            .if_not_exists()
                            .to_owned(),
                    )
                    .await?;
                Ok(())
            }

            async fn down(
                &self,
                manager: &SchemaManager,
            ) -> std::result::Result<(), sea_orm_migration::DbErr> {
                Ok(())
            }
        }
    }

    pub(crate) mod m000002_idx_chapter_cache_aid_cid {
        use sea_orm::sea_query::Index;
        use sea_orm::EntityName;
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000002_idx_chapter_cache_aid"
            }
        }

        #[async_trait::async_trait]
        impl MigrationTrait for Migration {
            async fn up(
                &self,
                manager: &SchemaManager,
            ) -> std::result::Result<(), sea_orm_migration::DbErr> {
                manager
                    .create_index(
                        Index::create()
                            .if_not_exists()
                            .name("idx_chapter_cache_aid")
                            .table(super::super::Entity.table_ref())
                            .col(super::super::Column::Aid)
                            .to_owned(),
                    )
                    .await?;
                Ok(())
            }

            async fn down(
                &self,
                manager: &SchemaManager,
            ) -> std::result::Result<(), sea_orm_migration::DbErr> {
                Ok(())
            }
        }
    }
}

impl Entity {
    pub async fn get_chapter_content(aid: &str, cid: &str) -> Result<Option<Model>, DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        let result = Entity::find()
            .filter(Column::Aid.eq(aid))
            .filter(Column::Cid.eq(cid))
            .one(db.deref())
            .await?;
        Ok(result)
    }

    /// 保存章节内容
    pub async fn save_chapter_content(
        aid: String,
        cid: String,
        content: String,
    ) -> Result<(), DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        let model = Model {
            aid,
            cid,
            content,
            download_time: chrono::Utc::now().timestamp(),
        };
        Entity::insert(model.into_active_model())
            .on_conflict(
                sea_orm::sea_query::OnConflict::columns(vec![Column::Aid, Column::Cid])
                    .update_column(Column::Content)
                    .update_column(Column::DownloadTime)
                    .to_owned(),
            )
            .exec(db.deref())
            .await?;
        Ok(())
    }

    /// 删除过期章节
    pub async fn delete_expired_chapters(time: i64) -> Result<(), DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        Entity::delete_many()
            .filter(Column::DownloadTime.lt(time))
            .exec(db.deref())
            .await?;
        Ok(())
    }
}
