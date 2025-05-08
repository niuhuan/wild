use sea_orm::{
    prelude::*,
    sea_query::{Index, SqliteQueryBuilder},
    Order, QueryOrder, Schema, Statement,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "reading_history")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    #[sea_orm(indexed)]
    pub novel_id: String,
    pub novel_name: String,
    pub chapter_id: String,
    pub chapter_title: String,
    pub last_read_at: i64,
    pub progress: i32, // 阅读进度 0-1
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub(super) mod migrations {

    pub(crate) mod m000001_create_table_reading_histories {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m00001_create_table_reading_histories"
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

    pub(crate) mod m000002_idx_reading_histories_novel_id {
        use sea_orm::sea_query::Index;
        use sea_orm::EntityName;
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000002_idx_reading_histories_novel_id"
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
                            .name("idx_reading_histories_novel_id")
                            .table(super::super::Entity.table_ref())
                            .col(super::super::Column::NovelId)
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
    /// 获取指定小说最新的阅读记录
    pub async fn find_latest_by_novel_id(novel_id: &str) -> crate::Result<Option<Model>> {
        let db = super::get_connect().await;
        let record = Entity::find()
            .filter(Column::NovelId.eq(novel_id))
            .order_by(Column::LastReadAt, Order::Desc)
            .one(&*db)
            .await?;
        Ok(record)
    }
}
