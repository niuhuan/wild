use std::ops::Deref;
use crate::wenku8::Wenku8Client;
use once_cell::sync::{Lazy, OnceCell};
use reqwest::cookie::Jar;
use reqwest::Client;
use std::sync::Arc;
use tokio::sync::Mutex;

mod api;
mod database;
mod frb_generated;
mod local;
#[cfg(test)]
mod test;
mod wenku8;

pub(crate) type Result<T> = anyhow::Result<T>;

pub(crate) static COOKIE_JAR: Lazy<Arc<Jar>> = Lazy::new(|| {
    let jar = Jar::default();
    Arc::new(jar)
});

pub(crate) static CLIENT: Lazy<Wenku8Client> = Lazy::new(|| {
    let cookie_jar = Arc::clone(COOKIE_JAR.deref());
    let client = Client::builder()
        .cookie_provider(cookie_jar.clone())
        .gzip(true)
        .build()
        .unwrap();
    Wenku8Client { client, cookie_jar }
});

static INIT_LOCK: OnceCell<Mutex<()>> = OnceCell::new();
static INIT_DONE: OnceCell<()> = OnceCell::new();

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
    database::init_database(&root).await?;

    // 标记初始化完成
    let _ = INIT_DONE.set(());

    Ok(())
}

fn save_cookies() -> Result<()> {
    Ok(())
}

fn load_cookies() -> Result<()> {
    Ok(())
}
