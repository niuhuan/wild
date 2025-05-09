use anyhow::Result;
use once_cell::sync::OnceCell;
use sea_orm::DatabaseConnection;
use std::path::Path;
use std::time::Duration;
use tokio::sync::Mutex;
use entities::active;
use entities::properties;

pub mod entities;

pub(crate) static PROPERTIES_DB_CONNECT: OnceCell<Mutex<DatabaseConnection>> = OnceCell::new();
pub(crate) static ACTIVE_DB_CONNECT: OnceCell<Mutex<DatabaseConnection>> = OnceCell::new();
pub(crate) static COOKIE_DB_CONNECT: OnceCell<Mutex<DatabaseConnection>> = OnceCell::new();

pub async fn init_database(root: &str) -> Result<()> {
    // 确保目录存在
    let db_dir = Path::new(root).join("database");
    std::fs::create_dir_all(&db_dir)?;

    // 初始化 properties 数据库
    let properties_path = db_dir.join("properties.db");
    let properties_db = connect_db(properties_path.to_str().unwrap()).await?;

    // 初始化 active 数据库
    let active_path = db_dir.join("active.db");
    let active_db = connect_db(active_path.to_str().unwrap()).await?;

    // 初始化 cookie 数据库
    let cookie_path = db_dir.join("cookie.db");
    let cookie_db = connect_db(cookie_path.to_str().unwrap()).await?;

    // 存储连接
    PROPERTIES_DB_CONNECT.set(Mutex::new(properties_db)).unwrap();
    ACTIVE_DB_CONNECT.set(Mutex::new(active_db)).unwrap();
    COOKIE_DB_CONNECT.set(Mutex::new(cookie_db)).unwrap();

    // 创建表和执行迁移
    properties::migrations().await?;
    active::migrations().await?;
    entities::cookie::migrations().await?;
    
    // 返回成功
    Ok(())
}

pub(crate) async fn connect_db(path: &str) -> Result<DatabaseConnection> {
    let url = format!("sqlite:{}?mode=rwc", path);
    println!("sqlite : {}", url);
    let mut opt = sea_orm::ConnectOptions::new(url);
    opt.max_connections(20)
        .min_connections(5)
        .connect_timeout(Duration::from_secs(8))
        .idle_timeout(Duration::from_secs(8))
        .sqlx_logging(true);
    Ok(sea_orm::Database::connect(opt).await?)
}

