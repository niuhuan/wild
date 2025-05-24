use crate::database::entities::active::{chapter_cache, image_cache, novel_download, novel_download_chapter, novel_download_picture, web_cache};
use crate::database::entities::WebCacheEntity;
use crate::{get_image_cache_dir, CLIENT, DOWNLOAD_FOLDER, IMAGE_LOCKS};
use chrono::Utc;
use image::io::Reader as ImageReader;
use image::GenericImageView;
use std::future::Future;
use std::path::Path;
use std::pin::Pin;
use std::time::Duration;
use tokio::fs as async_fs;

pub async fn cleanup_image_cache() -> crate::Result<()> {
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

pub async fn get_cached_image(img_url: String) -> crate::Result<String> {
    let image_cache_dir = get_image_cache_dir();
    let url_md5 = md5::compute(img_url.as_bytes()).0;
    let url_md5 = hex::encode(url_md5);
    let file_path = format!("{}/{}", image_cache_dir, url_md5);

    // 根据MD5最后一位选择锁
    let lock_index = (url_md5.as_bytes()[url_md5.len() - 1] % 64) as usize;
    let _guard = IMAGE_LOCKS[lock_index].lock().await;

    if let Some(a) = novel_download::Entity::find_by_image_url(img_url.as_str()).await? {
        if a.cover_download_status == 1 {
            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&a.novel_id);
            let picture_file_path = novel_dir.join("cover");
            let path = picture_file_path.to_str().unwrap().to_string(); 
            return Ok(path);
        }
    }

    if let Some(a) = novel_download_picture::Entity::find_by_url(img_url.as_str()).await? {
        if a.download_status == 1 {
            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&a.aid);
            let picture_file_path = novel_dir.join(format!("picture_{}", a.url_md5));
            let path = picture_file_path.to_str().unwrap().to_string();
            return Ok(path);
        }
    }

    // 检查缓存记录
    if let Some(_cache) = image_cache::Entity::find_by_url(img_url.as_str()).await? {
        // 如果缓存记录存在，尝试读取文件
        if Path::new(&file_path).exists() {
            return Ok(file_path);
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

    Ok(file_path)
}

pub(crate) async fn get_chapter_content(aid: &str, cid: &str) -> anyhow::Result<String> {
    // 根据MD5最后一位选择锁
    let url_md5 = md5::compute(format!("{aid}:{cid}").as_bytes()).0;
    let url_md5 = hex::encode(url_md5);
    let lock_index = (url_md5.as_bytes()[url_md5.len() - 1] % 64) as usize;
    let _guard = IMAGE_LOCKS[lock_index].lock().await;

    // 如果章节已下载，则直接从本地文件读取
    if let Some(a) = novel_download_chapter::Entity::find_by_id(cid).await? {
        if a.download_status == 1 {
            let novel_dir = Path::new(DOWNLOAD_FOLDER.get().unwrap()).join(&a.aid);
            let chapter_file_path = novel_dir.join(format!("chapter_{}", cid));
            let content = tokio::fs::read_to_string(chapter_file_path).await?;
            return Ok(content);
        }
    }

    // 先尝试从缓存获取
    if let Some(cache) = chapter_cache::Entity::get_chapter_content(aid, cid).await? {
        return Ok(cache.content);
    }

    // 下载章节内容
    let content = CLIENT.c_content(aid, cid).await?;

    // 保存到缓存
    chapter_cache::Entity::save_chapter_content(aid.to_string(), cid.to_string(), content.clone())
        .await?;

    Ok(content)
}

// 清理过期的章节缓存
pub(crate) async fn cleanup_expired_chapters() -> anyhow::Result<()> {
    // 清理7天前的缓存
    let expire_time = Utc::now().timestamp() - 7 * 24 * 60 * 60;
    chapter_cache::Entity::delete_expired_chapters(expire_time).await?;
    Ok(())
}

// 清理过期的web缓存
pub(crate) async fn cleanup_expired_web_cache() -> anyhow::Result<()> {
    // 清理7天前的缓存
    let expire_time = Utc::now().timestamp() - 7 * 24 * 60 * 60;
    web_cache::Entity::delete_expired_cache(expire_time).await?;
    Ok(())
}

pub(crate) async fn cache_first<T: for<'de> serde::Deserialize<'de> + serde::Serialize>(
    key: String,
    expire: Duration,
    pin: Pin<Box<dyn Future<Output = anyhow::Result<T>> + Send>>,
) -> anyhow::Result<T> {
    let lock_index = (key.as_bytes()[key.len() - 1] % 64) as usize;
    let _guard = IMAGE_LOCKS[lock_index].lock().await;
    let time = chrono::Local::now().timestamp();
    if let Some(ref model) = WebCacheEntity::get_web_cache(key.as_str()).await? {
        if time < (model.cache_time + expire.as_secs() as i64) {
            Ok(serde_json::from_str(&model.cache_content)?)
        } else {
            let t = pin.await?;
            let content = serde_json::to_string(&t)?;
            WebCacheEntity::update_web_cache(key, content).await?;
            Ok(t)
        }
    } else {
        let t = pin.await?;
        let content = serde_json::to_string(&t)?;
        WebCacheEntity::save_web_cache(key, content).await?;
        Ok(t)
    }
}
