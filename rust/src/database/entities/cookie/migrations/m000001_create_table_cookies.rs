use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Cookies::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Cookies::Id)
                            .integer()
                            .not_null()
                            .auto_increment()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Cookies::Domain).string().not_null())
                    .col(ColumnDef::new(Cookies::Name).string().not_null())
                    .col(ColumnDef::new(Cookies::Value).string().not_null())
                    .col(ColumnDef::new(Cookies::Path).string().not_null())
                    .col(ColumnDef::new(Cookies::Expires).big_integer().null())
                    .col(ColumnDef::new(Cookies::Secure).boolean().not_null())
                    .col(ColumnDef::new(Cookies::HttpOnly).boolean().not_null())
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Cookies::Table).to_owned())
            .await
    }
}

#[derive(Iden)]
enum Cookies {
    Table,
    Id,
    Domain,
    Name,
    Value,
    Path,
    Expires,
    Secure,
    HttpOnly,
} 