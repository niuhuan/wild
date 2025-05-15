use std::ops::Deref;

use sea_orm::entity::prelude::*;
use sea_orm::ActiveValue::Set;
use sea_orm::IntoActiveModel;
use sea_orm_migration::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "cookie")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub domain: String,
    #[sea_orm(primary_key)]
    pub name: String,
    pub value: String,
    pub path: String,
    pub expires: Option<i64>,
    pub secure: Option<bool>,
    pub http_only: Option<bool>,
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

    pub async fn save_or_update_cookie(cookie: Model) -> crate::Result<()> {
        let db = super::get_connect().await;
        let exists = Entity::find()
            .filter(Column::Domain.eq(cookie.domain.as_str()))
            .filter(Column::Name.eq(cookie.name.as_str()))
            .one(db.deref())
            .await?;
        if let Some(exists) = exists {
            Entity::update(cookie.clone().into_active_model())
                .filter(Column::Domain.eq(cookie.domain.as_str()))
                .filter(Column::Name.eq(cookie.name.as_str()))
                .exec(db.deref())
                .await?;
        } else {
            Entity::insert(cookie.into_active_model())
                .exec(db.deref())
                .await?;
        }
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
    
    pub async fn exists(name: &str) -> crate::Result<bool> {
        let db = super::get_connect().await;
        let exists = Entity::find()
            .filter(Column::Name.eq(name))
            .count(db.deref())
            .await?;
        Ok(exists > 0)
    }
    
    pub async fn delete_all() -> crate::Result<()> {
        let db = super::get_connect().await;
        Entity::delete_many()
            .exec(db.deref())
            .await?;
        Ok(())
    }
}
