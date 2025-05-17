use sea_orm::{prelude::*, sea_query::{Index, SqliteQueryBuilder}, Order, QueryOrder, QuerySelect, Schema, Set, Statement};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use flutter_rust_bridge::frb;

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "reading_history")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub novel_id: String,
    pub novel_name: String,
    pub volume_id: String,
    pub volume_name: String,
    pub chapter_id: String,
    pub chapter_title: String,
    pub last_read_at: i64,
    pub progress: i32,
    pub cover: String,
    pub author: String,
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
                "m000001_create_table_reading_histories"
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

    pub(crate) mod m000003_create_table_reading_histories_volume {
        use sea_orm::sea_query::{Index, Table};
        use sea_orm::{ColumnTrait, ConnectionTrait, EntityName, IdenStatic, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000003_create_table_reading_histories_volume"
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
                if !manager
                    .has_column(
                        super::super::Entity.table_name(),
                        super::super::Column::VolumeId.as_str(),
                    )
                    .await?
                {
                    manager
                        .alter_table(
                            Table::alter()
                                .table(super::super::Entity.table_ref())
                                .add_column(&mut schema.get_column_def::<super::super::Entity>(
                                    super::super::Column::VolumeId,
                                ))
                                .to_owned(),
                        )
                        .await?;
                }
                if !manager
                    .has_column(
                        super::super::Entity.table_name(),
                        super::super::Column::NovelId.as_str(),
                    )
                    .await?
                {
                    manager
                        .alter_table(
                            Table::alter()
                                .table(super::super::Entity.table_ref())
                                .add_column(&mut schema.get_column_def::<super::super::Entity>(
                                    super::super::Column::NovelId,
                                ))
                                .to_owned(),
                        )
                        .await?;
                }
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


    pub(crate) mod m000003_create_table_reading_histories_cover_author {
        use sea_orm::sea_query::{Index, Table};
        use sea_orm::{ColumnTrait, ConnectionTrait, EntityName, IdenStatic, Schema};
        use sea_orm_migration::{MigrationName, MigrationTrait, SchemaManager};

        pub struct Migration;

        impl MigrationName for Migration {
            fn name(&self) -> &str {
                "m000003_create_table_reading_histories_cover_author"
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
                if !manager
                    .has_column(
                        super::super::Entity.table_name(),
                        super::super::Column::Cover.as_str(),
                    )
                    .await?
                {
                    manager
                        .alter_table(
                            Table::alter()
                                .table(super::super::Entity.table_ref())
                                .add_column(&mut schema.get_column_def::<super::super::Entity>(
                                    super::super::Column::Cover,
                                ))
                                .to_owned(),
                        )
                        .await?;
                }
                if !manager
                    .has_column(
                        super::super::Entity.table_name(),
                        super::super::Column::Author.as_str(),
                    )
                    .await?
                {
                    manager
                        .alter_table(
                            Table::alter()
                                .table(super::super::Entity.table_ref())
                                .add_column(&mut schema.get_column_def::<super::super::Entity>(
                                    super::super::Column::Author,
                                ))
                                .to_owned(),
                        )
                        .await?;
                }
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
    pub async fn list_reading_history(offset: i32, limit: i32) -> crate::Result<Vec<Model>> {
        let db = super::get_connect().await;
        let records = Entity::find()
            .order_by(Column::LastReadAt, Order::Desc)
            .offset(offset as u64)
            .limit(limit as u64)
            .all(&*db)
            .await?;
        Ok(records)
    }
    
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

    pub async fn upsert(
        novel_id: &str,
        novel_name: &str,
        volume_id: &str,
        volume_name: &str,
        chapter_id: &str,
        chapter_title: &str,
        progress: i32,
        cover: &str,
        author: &str,
    ) -> crate::Result<()> {
        let db = super::get_connect().await;
        let time = chrono::Local::now().timestamp_millis();
        let model = ActiveModel {
            novel_id: Set(novel_id.to_string()),
            novel_name: Set(novel_name.to_string()),
            volume_id: Set(volume_id.to_string()),
            volume_name: Set(volume_name.to_string()),
            chapter_id: Set(chapter_id.to_string()),
            chapter_title: Set(chapter_title.to_string()),
            last_read_at: Set(time),
            progress: Set(progress),
            cover: Set(cover.to_string()),
            author: Set(author.to_string()),
        };
        if let Some(_existing_record) = Entity::find_by_id(novel_id).one(db.deref()).await? {
            // 如果记录已存在，则更新
            model.update(db.deref()).await?;
        } else {
            // 如果记录不存在，则插入
            model.insert(db.deref()).await?;
        }
        Ok(())
    }

    /// 删除100条以后的阅读历史记录
    pub async fn delete_old_records() -> crate::Result<()> {
        let db = super::get_connect().await;
        // 先获取最新的100条记录
        let records = Entity::find()
            .order_by(Column::LastReadAt, Order::Desc)
            .limit(100)
            .all(db.deref())
            .await?;

        if records.len() < 100 {
            return Ok(());
        }

        // 获取第100条记录的时间
        let cutoff_time = records.last().unwrap().last_read_at;

        // 删除这个时间点之前的记录
        Entity::delete_many()
            .filter(Column::LastReadAt.lt(cutoff_time))
            .exec(db.deref())
            .await?;

        Ok(())
    }

    pub async fn delete_all() -> crate::Result<()> {
        let db = super::get_connect().await;
        Entity::delete_many().exec(db.deref()).await?;
        Ok(())
    }
}
