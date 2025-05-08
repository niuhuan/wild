use std::ops::Deref;

use sea_orm::entity::prelude::*;
use sea_orm::ActiveValue::Set;
use sea_orm_migration::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "cookie")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    pub domain: String,
    pub name: String,
    pub value: String,
    pub path: String,
    pub expires: Option<i64>,
    pub secure: bool,
    pub http_only: bool,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

impl Entity {
    pub async fn find_by_domain(domain: &str) -> crate::Result<Vec<Model>> {
        let db = super::get_connect().await;
        Ok(Entity::find()
            .filter(Column::Domain.eq(domain))
            .all(db.deref())
            .await?)
    }

    pub async fn save_cookie(cookie: Model) -> crate::Result<()> {
        let db = super::get_connect().await;
        let active_model = ActiveModel {
            id: Set(cookie.id),
            domain: Set(cookie.domain),
            name: Set(cookie.name),
            value: Set(cookie.value),
            path: Set(cookie.path),
            expires: Set(cookie.expires),
            secure: Set(cookie.secure),
            http_only: Set(cookie.http_only),
        };
        active_model.insert(db.deref()).await?;
        Ok(())
    }

    pub async fn delete_by_domain(domain: &str) -> crate::Result<()> {
        let db = super::get_connect().await;
        Entity::delete_many()
            .filter(Column::Domain.eq(domain))
            .exec(db.deref())
            .await?;
        Ok(())
    }
} 
