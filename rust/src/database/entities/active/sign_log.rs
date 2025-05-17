use sea_orm::{prelude::*, sea_query::{Index, SqliteQueryBuilder}, Order, QueryOrder, QuerySelect, Schema, Set, Statement};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use flutter_rust_bridge::frb;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "sign_log")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub date: String, // 格式：YYYY-MM-DD
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub(super) mod migrations {
    pub(crate) mod m000001_create_table_sign_log {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000001_create_table_sign_log"
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
}

impl Entity {
    /// 添加签到记录
    pub async fn sign() -> crate::Result<()> {
        let db = super::get_connect().await;
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let model = ActiveModel {
            date: Set(today),
        };
        model.insert(db.deref()).await?;
        Ok(())
    }

    /// 检查今天是否已签到
    pub async fn is_signed_today() -> crate::Result<bool> {
        let db = super::get_connect().await;
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let record = Entity::find_by_id(today).one(db.deref()).await?;
        Ok(record.is_some())
    }

    /// 获取签到记录列表
    pub async fn list_sign_log(offset: i32, limit: i32) -> crate::Result<Vec<Model>> {
        let db = super::get_connect().await;
        let records = Entity::find()
            .order_by(Column::Date, Order::Desc)
            .offset(offset as u64)
            .limit(limit as u64)
            .all(&*db)
            .await?;
        Ok(records)
    }

    /// 删除100条以后的签到记录
    pub async fn delete_old_records() -> crate::Result<()> {
        let db = super::get_connect().await;
        // 先获取最新的100条记录
        let records = Entity::find()
            .order_by(Column::Date, Order::Desc)
            .limit(100)
            .all(db.deref())
            .await?;

        if records.len() < 100 {
            return Ok(());
        }

        // 获取第100条记录的日期
        let cutoff_date = records.last().unwrap().date.clone();

        // 删除这个日期之前的记录
        Entity::delete_many()
            .filter(Column::Date.lt(cutoff_date))
            .exec(db.deref())
            .await?;

        Ok(())
    }

    /// 删除所有签到记录
    pub async fn delete_all() -> crate::Result<()> {
        let db = super::get_connect().await;
        Entity::delete_many().exec(db.deref()).await?;
        Ok(())
    }
} 