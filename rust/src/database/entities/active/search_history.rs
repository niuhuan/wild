use sea_orm::entity::prelude::*;
use sea_orm::{ActiveValue::Set, IntoActiveModel, QueryOrder, QuerySelect};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use super::get_connect;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "search_history")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub search_type: String,
    #[sea_orm(primary_key, auto_increment = false)]
    pub search_key: String,
    pub search_time: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {
    /// 按照时间倒序获取所有搜索记录
    pub async fn list_all() -> crate::Result<Vec<Model>> {
        let db = get_connect().await;
        Ok(Entity::find()
            .order_by_desc(Column::SearchTime)
            .all(db.deref())
            .await?)
    }

    /// 按照时间倒序获取指定类型的搜索记录
    pub async fn list_by_type(search_type: &str) -> crate::Result<Vec<Model>> {
        let db = get_connect().await;
        Ok(Entity::find()
            .filter(Column::SearchType.eq(search_type))
            .order_by_desc(Column::SearchTime)
            .all(db.deref())
            .await?)
    }

    /// 删除100条以后的记录
    pub async fn delete_old_records() -> crate::Result<()> {
        let db = get_connect().await;
        // 先获取第100条记录的时间
        let records = Entity::find()
            .order_by_desc(Column::SearchTime)
            .limit(100)
            .all(db.deref())
            .await?;
        
        if records.len() < 100 {
            return Ok(());
        }

        // 获取第100条记录的时间
        let cutoff_time = records.last().unwrap().search_time;
        
        // 删除这个时间点之前的记录
        Entity::delete_many()
            .filter(Column::SearchTime.lt(cutoff_time))
            .exec(db.deref())
            .await?;
        
        Ok(())
    }

    /// 保存或更新搜索记录
    pub async fn save_or_update(search_type: String, search_key: String) -> crate::Result<()> {
        let db = get_connect().await;
        let now = chrono::Utc::now().timestamp();
        
        // 检查记录是否存在
        let exists = Entity::find()
            .filter(Column::SearchType.eq(search_type.as_str()))
            .filter(Column::SearchKey.eq(search_key.as_str()))
            .one(db.deref())
            .await?;

        if let Some(exists) = exists {
            // 更新已存在的记录
            let mut model = exists.into_active_model();
            model.search_time = Set(now);
            model.update(db.deref()).await?;
        } else {
            // 插入新记录
            let model = ActiveModel {
                search_type: Set(search_type),
                search_key: Set(search_key),
                search_time: Set(now),
            };
            model.insert(db.deref()).await?;
        }
        
        Ok(())
    }
}

pub(super) mod migrations {
    pub(crate) mod m000001_create_table_search_history {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000001_create_table_search_history"
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

    pub(crate) mod m000002_idx_search_history_time {
        use sea_orm::sea_query::Index;
        use sea_orm::EntityName;
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000002_idx_search_history_time"
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
                            .name("idx_search_history_time")
                            .table(super::super::Entity.table_ref())
                            .col(super::super::Column::SearchTime)
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

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelatedEntity)]
pub enum RelatedEntity {} 