use crate::api::database::save_property;
use crate::wenku8::Wenku8Client;
use crate::{
    api::database::load_property, database::entities::cookie::cookie_store::DatabaseCookieStore,
};
pub(crate) use cache_manager::*;
use once_cell::sync::{Lazy, OnceCell};
use rand::seq::IndexedRandom;
use rand::Rng;
use reqwest::Client;
use std::ops::Deref;
use std::path::Path;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};

mod api;
mod cache_manager;
mod database;
mod downloading;
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
    Wenku8Client {
        client,
        user_agent: RwLock::new("".to_string()),
        api_host: RwLock::new("".to_string()),
    }
});

static INIT_LOCK: OnceCell<Mutex<()>> = OnceCell::new();
static INIT_DONE: OnceCell<()> = OnceCell::new();
static IMAGE_CACHE_DIR: OnceCell<String> = OnceCell::new();
pub(crate) static DOWNLOAD_FOLDER: OnceCell<String> = OnceCell::new();

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
    // 创建下载目录
    let download_folder = Path::new(&root).join("download");
    std::fs::create_dir_all(&download_folder)?;
    DOWNLOAD_FOLDER
        .set(download_folder.to_str().unwrap().to_string())
        .unwrap();

    // 清理过期的图片缓存
    cleanup_image_cache().await?;
    cleanup_expired_chapters().await?;
    cleanup_expired_web_cache().await?;

    init_user_agent().await?;
    init_api_host().await?;

    downloading::start_downloading().await?;

    // 标记初始化完成
    let _ = INIT_DONE.set(());

    Ok(())
}

async fn init_api_host() -> Result<()> {
    let mut property_api_host = load_property("api_host".to_string()).await?;
    if !property_api_host.is_empty() {
        CLIENT.set_api_host(property_api_host).await;
    }
    Ok(())
}

pub async fn set_api_host(api_host: String) -> Result<()> {
    save_property("api_host".to_string(), api_host.clone()).await?;
    CLIENT.set_api_host(api_host).await;
    Ok(())
}

pub fn get_image_cache_dir() -> &'static str {
    IMAGE_CACHE_DIR.get().unwrap()
}

async fn init_user_agent() -> Result<()> {
    let mut property_user_agent = load_property("user_agent".to_string()).await?;
    if property_user_agent.is_empty() {
        property_user_agent = random_user_agent();
        save_property("user_agent".to_string(), property_user_agent.clone()).await?;
    }
    if !property_user_agent.starts_with("Dalvik") {
        property_user_agent = random_user_agent();
        save_property("user_agent".to_string(), property_user_agent.clone()).await?;
    }
    CLIENT.set_user_agent(property_user_agent).await;
    Ok(())
}

fn random_user_agent() -> String {
    random_android_ua()
}

const ANDROID_VERSIONS: &[&str] = &[
    "4.4", "5.0", "5.1", "6.0", "7.0", "7.1", "8.0", "8.1", "9", "10", "11", "12", "12.1", "13",
    "14", "15",
];

// 常见设备名，包括模拟器和主流品牌型号
const DEVICES: &[&str] = &[
    "Android SDK built for arm64",
    "Android SDK built for x86",
    "Pixel 7 Pro",
    "Pixel 7",
    "Pixel 6 Pro",
    "Pixel 6",
    "Pixel 5",
    "Pixel 4 XL",
    "Pixel 4a",
    "Pixel 3",
    "Redmi Note 12 Pro",
    "Redmi Note 11",
    "Redmi K60",
    "Redmi 10X",
    "MI 13",
    "MI 12",
    "MI 11 Ultra",
    "MI 10",
    "MI 9",
    "HUAWEI Mate 60 Pro",
    "HUAWEI P60",
    "HUAWEI nova 12",
    "HUAWEI Mate 40",
    "HUAWEI P40",
    "HUAWEI Mate X5",
    "OPPO Find X7",
    "OPPO Reno11",
    "OPPO A78",
    "Vivo X100",
    "Vivo S18",
    "Vivo Y100",
    "OnePlus 12",
    "OnePlus 11",
    "OnePlus 9 Pro",
    "realme GT5",
    "realme 12 Pro",
    "Samsung Galaxy S24",
    "Samsung Galaxy S23 Ultra",
    "Samsung Galaxy S22",
    "Samsung Galaxy Note10+",
    "Meizu 21 Pro",
    "Meizu 20",
    "Lenovo Legion Y70",
    "Lenovo K12",
    "Sony Xperia 1V",
    "Sony Xperia 10V",
];

// 常见 Build 前缀（按 Android 版本/厂商编译习惯）
const BUILD_PREFIXES: &[&str] = &[
    "AE3A",
    "TP1A",
    "UP1A",
    "SP1A",
    "RQ2A",
    "QQ3A",
    "RP1A",
    "QP1A",
    "RKQ1",
    "PKQ1",
    "SQ3A",
    "TQ3A",
    "UQ1A",
    "VQ1A",
    "WW",
    "HMKQ1",
    "V12.5.2.0",
    "V13.0.1.0",
    "V14.0.4.0",
];

fn random_build_id() -> String {
    let mut rng = rand::rng();
    let prefix = BUILD_PREFIXES.choose(&mut rng).unwrap();
    let year = rng.random_range(20..=25);
    let month = rng.random_range(1..=12);
    let day = rng.random_range(1..=28);
    format!(
        "{}.{}{:02}{:02}.{:03}",
        prefix,
        year,
        month,
        day,
        rng.random_range(1..=999)
    )
}

fn random_fire_fox_version() -> String {
    let mut rng = rand::rng();
    let version = rng.random_range(85..=140);
    format!("{}", version)
}

fn random_android_ua() -> String {
    // let mut rng = rand::rng();
    // let android_version = ANDROID_VERSIONS.choose(&mut rng).unwrap();
    // let device = DEVICES.choose(&mut rng).unwrap();
    // let build_id = random_build_id();
    // let firefox_version = random_fire_fox_version();
    // format!(
    //     // "Dalvik/2.1.0 (Linux; U; Android {}; {} Build/{}) Gecko/20100101 Firefox/{}.0",
    //     "Dalvik/2.1.0 (Linux; U; Android 15; {} Build/AQ3A.{}.{})",
    //     device, build_id, firefox_version
    // )
    "Dalvik/2.1.0 (Linux; U; Android 15; 23114RD76B Build/AQ3A.240912.001)".to_string()
}
