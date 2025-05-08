use sea_orm::entity::prelude::*;
use sea_orm::{ConnectionTrait,  Schema, Set};
use serde::{Deserialize, Serialize};
use anyhow::Result;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "properties")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub key: String,
    pub value: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub(super) mod migrations {

    pub(crate) mod m000001_create_table_properties {
        use sea_orm::{ConnectionTrait, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000001_create_table_properties"
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

    /// 获取属性值
    pub async fn get_value(key: &str) -> Result<Option<String>> {
        let db = super::get_connect().await;
        let record = Entity::find_by_id(key)
            .one(&*db)
            .await?;
        Ok(record.map(|m| m.value))
    }

    /// 设置属性值
    pub async fn set_value(key: String, value: String) -> Result<()> {
        let db = super::get_connect().await;
        let model = ActiveModel {
            key: Set(key),
            value: Set(value),
        };
        Entity::insert(model)
            .on_conflict(
                sea_orm::sea_query::OnConflict::column(Column::Key)
                    .update_column(Column::Value)
                    .to_owned()
            )
            .exec(&*db)
            .await?;
        Ok(())
    }
} 