use crate::database;
use sea_orm::{prelude::*, IntoActiveModel};
use serde::{Deserialize, Serialize};
use std::ops::Deref;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "image_cache")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub img_url: String,
    pub url_md5: String,
    pub width: i32,
    pub height: i32,
    pub file_size: i64,
    pub download_time: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub(super) mod migrations {
    pub(crate) mod m000001_create_table_image_cache {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000001_create_table_image_cache"
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

    pub(crate) mod m000002_idx_image_cache_url_md5 {
        use sea_orm::sea_query::Index;
        use sea_orm::EntityName;
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000002_idx_image_cache_url_md5"
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
                            .name("idx_image_cache_url_md5")
                            .table(super::super::Entity.table_ref())
                            .col(super::super::Column::UrlMd5)
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

    pub async fn expired_images(time: i64) -> Result<Vec<Model>, DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        let expired_records = Self::find()
            .filter(Column::DownloadTime.lt(time))
            .all(db.deref())
            .await?;
        Ok(expired_records)
    }

    pub async fn find_by_url(img_url: &str) -> Result<Option<Model>, DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        if let Some(cache) = Self::find_by_id(img_url.to_string())
            .one(db.deref())
            .await?
        {
            Ok(Some(cache))
        } else {
            Ok(None)
        }
    }

    pub async fn save_image_cache(model: Model) -> Result<(), DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        Entity::insert(model.into_active_model())
            .exec(db.deref())
            .await?;
        Ok(())
    }

    pub async fn delete_by_url_list(url_list: Vec<String>) -> Result<(), DbErr> {
        let db = database::ACTIVE_DB_CONNECT.get().unwrap().lock().await;
        Entity::delete_many()
            .filter(Column::ImgUrl.is_in(url_list))
            .exec(db.deref())
            .await?;
        Ok(())
    }
}
