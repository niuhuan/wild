use crate::database::entities::cookie::cookie_store::DatabaseCookieStore;
use crate::wenku8::Wenku8Client;
use image::GenericImageView;
use once_cell::sync::{Lazy, OnceCell};
use reqwest::Client;
use sea_orm::{EntityTrait, QueryFilter};
use std::future::Future;
use std::ops::Deref;
use std::path::Path;
use std::sync::Arc;
use tokio::sync::Mutex;
pub(crate) use cache_manager::*;

mod api;
mod database;
mod frb_generated;
mod local;
#[cfg(test)]
mod test;
mod wenku8;
mod cache_manager;
mod downloading;

pub(crate) type Result<T> = anyhow::Result<T>;

pub(crate) static COOKIE_STORE: Lazy<Arc<DatabaseCookieStore>> =
    Lazy::new(|| Arc::new(DatabaseCookieStore {}));

pub(crate) static CLIENT: Lazy<Wenku8Client> = Lazy::new(|| {
    let cookie_store = Arc::clone(COOKIE_STORE.deref());
    let client = Client::builder()
        .cookie_provider(cookie_store)
        .gzip(true)
        .build()
        .unwrap();
    Wenku8Client { client }
});

static INIT_LOCK: OnceCell<Mutex<()>> = OnceCell::new();
static INIT_DONE: OnceCell<()> = OnceCell::new();
static IMAGE_CACHE_DIR: OnceCell<String> = OnceCell::new();

// 创建64个锁，用于防止同一个URL的并发下载
static IMAGE_LOCKS: Lazy<Vec<Mutex<()>>> = Lazy::new(|| {
    let mut locks = Vec::with_capacity(64);
    for _ in 0..64 {
        locks.push(Mutex::new(()));
    }
    locks
});

/// 全局初始化函数
/// 只会执行一次，重复调用会直接返回
/// 使用 Mutex 确保初始化过程不会并发执行
pub async fn init(root: String) -> Result<()> {
    // 确保 INIT_LOCK 已初始化
    let lock = INIT_LOCK.get_or_init(|| Mutex::new(()));

    // 如果已经初始化完成，直接返回
    if INIT_DONE.get().is_some() {
        return Ok(());
    }
    // 确保根目录存在
    std::fs::create_dir_all(&root)?;

    // 获取锁，确保只有一个初始化过程在执行
    let _guard = lock.lock().await;

    // 双重检查，防止在等待锁的过程中已经被其他线程初始化完成
    if INIT_DONE.get().is_some() {
        return Ok(());
    }

    // 执行实际的初始化
    database::init_database(root.as_str()).await?;

    // 创建图片缓存目录
    let image_cache_dir = Path::new(&root).join("image_cache");
    std::fs::create_dir_all(&image_cache_dir)?;
    IMAGE_CACHE_DIR
        .set(image_cache_dir.to_str().unwrap().to_string())
        .unwrap();

    // 清理过期的图片缓存
    cleanup_image_cache().await?;
    cleanup_expired_chapters().await?;
    cleanup_expired_web_cache().await?;

    // 标记初始化完成
    let _ = INIT_DONE.set(());

    Ok(())
}

pub fn get_image_cache_dir() -> &'static str {
    IMAGE_CACHE_DIR.get().unwrap()
}