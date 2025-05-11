use crate::database::entities::active::image_cache;
use crate::database::entities::cookie::cookie_store::DatabaseCookieStore;
use crate::wenku8::Wenku8Client;
use chrono::Utc;
use image::io::Reader as ImageReader;
use image::GenericImageView;
use once_cell::sync::{Lazy, OnceCell};
use reqwest::Client;
use sea_orm::{EntityTrait, QueryFilter, Set};
use std::ops::Deref;
use std::path::Path;
use std::sync::Arc;
use tokio::fs as async_fs;
use tokio::sync::Mutex;

mod api;
mod database;
mod frb_generated;
mod local;
#[cfg(test)]
mod test;
mod wenku8;

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

    // 标记初始化完成
    let _ = INIT_DONE.set(());

    Ok(())
}

pub async fn cleanup_image_cache() -> Result<()> {
    let image_cache_dir = get_image_cache_dir();
    let seven_days_ago = Utc::now().timestamp() - (7 * 24 * 60 * 60);
    let expired_records = image_cache::Entity::expired_images(seven_days_ago).await?;
    // 删除过期的文件
    for record in &expired_records {
        let file_path = format!("{}/{}", image_cache_dir, record.url_md5);
        if Path::new(&file_path).exists() {
            let _ = async_fs::remove_file(file_path).await;
        }
    }
    // 删除过期的数据库记录
    image_cache::Entity::delete_by_url_list(
        expired_records
            .iter()
            .map(|record| record.img_url.clone())
            .collect(),
    )
    .await?;
    Ok(())
}

pub async fn get_cached_image(img_url: String) -> Result<Vec<u8>> {
    let image_cache_dir = get_image_cache_dir();
    let url_md5 = md5::compute(img_url.as_bytes()).0;
    let url_md5 = hex::encode(url_md5);
    let file_path = format!("{}/{}", image_cache_dir, url_md5);

    // 根据MD5最后一位选择锁
    let lock_index = (url_md5.as_bytes()[url_md5.len() - 1] % 64) as usize;
    let _guard = IMAGE_LOCKS[lock_index].lock().await;

    // 检查缓存记录
    if let Some(_cache) = image_cache::Entity::find_by_url(img_url.as_str()).await? {
        // 如果缓存记录存在，尝试读取文件
        if Path::new(&file_path).exists() {
            return Ok(async_fs::read(file_path).await?);
        }
    }

    // 缓存未命中，下载图片
    let buff = CLIENT.download_image(img_url.as_str()).await?;

    // 获取图片尺寸
    let img = ImageReader::new(std::io::Cursor::new(&buff))
        .with_guessed_format()?
        .decode()?;
    let (width, height) = img.dimensions();

    // 保存文件
    async_fs::write(&file_path, &buff).await?;

    // 保存数据库记录
    let cache = image_cache::Model {
        img_url,
        url_md5,
        width: width as i32,
        height: height as i32,
        file_size: buff.len() as i64,
        download_time: Utc::now().timestamp(),
    };
    image_cache::Entity::save_image_cache(cache).await?;

    Ok(buff)
}

pub fn get_image_cache_dir() -> &'static str {
    IMAGE_CACHE_DIR.get().unwrap()
}

pub(crate) async fn get_chapter_content(aid: &str, cid: &str) -> anyhow::Result<String> {
    CLIENT.c_content(aid, cid).await
}