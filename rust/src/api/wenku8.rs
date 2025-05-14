use crate::database::entities::active::reading_history::Model;
use crate::database::entities::ReadingHistoryEntity;
use crate::wenku8::{
    BookshelfItem, HomeBlock, NovelCover, NovelInfo, PageStats, TagGroup, UserDetail, Volume,
};
use crate::Result;
use crate::CLIENT;
use std::time::Duration;
use serde::{Deserialize, Serialize};

#[flutter_rust_bridge::frb]
pub async fn wenku8_login(username: String, password: String, checkcode: String) -> Result<()> {
    CLIENT.login(&username, &password, &checkcode).await
}

#[flutter_rust_bridge::frb]
pub async fn wenku8_get_bookshelf() -> Result<Vec<BookshelfItem>> {
    CLIENT.get_bookshelf().await
}

pub async fn pre_login_state() -> Result<bool> {
    let logged = crate::database::entities::CookieEntity::exists("jieqiUserInfo").await?;
    Ok(logged)
}

pub async fn download_checkcode() -> Result<Vec<u8>> {
    CLIENT.checkcode().await
}

pub async fn user_detail() -> Result<UserDetail> {
    CLIENT.userdetail().await
}

pub async fn index() -> anyhow::Result<Vec<HomeBlock>> {
    let key = "INDEX_DATA".to_string();
    crate::cache_first(
        key,
        Duration::from_secs(60 * 10),
        Box::pin(async move { CLIENT.index().await }),
    )
    .await
}

pub async fn download_image(url: String) -> anyhow::Result<Vec<u8>> {
    crate::get_cached_image(url).await
}

pub async fn chapter_content(aid: String, cid: String) -> anyhow::Result<String> {
    let content = crate::get_chapter_content(&aid, &cid).await?;

    // 处理内容中的空白字符
    let processed_content = content
        .lines() // 按行分割
        .filter(|line| !line.trim().is_empty()) // 移除空行
        .collect::<Vec<&str>>()
        .join("\n") // 重新组合，每行之间用单个换行符连接
        .replace(|c: char| c.is_whitespace() && c != '\n', " "); // 将其他空白字符替换为空格

    // 将连续的两个以上换行符替换为两个换行符
    let mut result = String::new();
    let mut newline_count = 0;

    for c in processed_content.chars() {
        if c == '\n' {
            newline_count += 1;
            if newline_count <= 2 {
                result.push(c);
            }
        } else {
            if newline_count > 2 {
                // 如果之前有超过两个换行符，添加两个换行符
                result.push('\n');
                result.push('\n');
            }
            newline_count = 0;
            result.push(c);
        }
    }

    Ok(result)
}

pub async fn novel_info(aid: String) -> anyhow::Result<NovelInfo> {
    let key = format!("NOVEL_INFO${}", aid);
    crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.novel_info(&aid).await }),
    )
    .await
}

pub async fn novel_reader(aid: String) -> anyhow::Result<Vec<Volume>> {
    let key = format!("NOVEL_READER${}", aid);
    crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.novel_reader(&aid).await }),
    )
    .await
}

pub async fn update_history(
    novel_id: &str,
    novel_name: &str,
    volume_id: &str,
    volume_name: &str,
    chapter_id: &str,
    chapter_title: &str,
    progress: i32,
    cover: &str,
    author: &str,
) -> anyhow::Result<()> {
    ReadingHistoryEntity::upsert(
        novel_id,
        novel_name,
        volume_id,
        volume_name,
        chapter_id,
        chapter_title,
        progress,
        cover,
        author,
    )
    .await?;
    Ok(())
}

pub struct ReadingHistory {
    pub novel_id: String,
    pub novel_name: String,
    pub volume_id: String,
    pub volume_name: String,
    pub chapter_id: String,
    pub chapter_title: String,
    pub last_read_at: i64,
    pub progress: i32, // 阅读进度 0-1
    pub cover: String,
    pub author: String,
}

pub async fn novel_history_by_id(novel_id: &str) -> anyhow::Result<Option<ReadingHistory>> {
    Ok(ReadingHistoryEntity::find_latest_by_novel_id(novel_id)
        .await?
        .map(|history| ReadingHistory {
            novel_id: history.novel_id,
            novel_name: history.novel_name,
            volume_id: history.volume_id,
            volume_name: history.volume_name,
            chapter_id: history.chapter_id,
            chapter_title: history.chapter_title,
            last_read_at: history.last_read_at,
            progress: history.progress,
            cover: history.cover,
            author: history.author,
        }))
}

pub async fn list_reading_history(offset: i32, limit: i32) -> crate::Result<Vec<ReadingHistory>> {
    let histories = ReadingHistoryEntity::list_reading_history(offset, limit).await?;
    Ok(histories
        .into_iter()
        .map(|history| ReadingHistory {
            novel_id: history.novel_id,
            novel_name: history.novel_name,
            volume_id: history.volume_id,
            volume_name: history.volume_name,
            chapter_id: history.chapter_id,
            chapter_title: history.chapter_title,
            last_read_at: history.last_read_at,
            progress: history.progress,
            cover: history.cover,
            author: history.author,
        })
        .collect())
}

pub async fn tags() -> crate::Result<Vec<TagGroup>> {
    let key = "TAGS".to_string();
    crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.tags().await }),
    )
    .await
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct PageStatsNovelCover {
    pub current_page: i32,
    pub max_page: i32,
    pub records: Vec<NovelCover>,
}

pub async fn tag_page(
    tag: String,
    v: String,
    page_number: i32,
) -> anyhow::Result<PageStatsNovelCover> {
    let key = format!("TAG_PAGE${}${}${}", tag, v, page_number);
    let data = crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.tag_page(&tag, &v, page_number).await }),
    )
    .await?;
    Ok(PageStatsNovelCover {
        current_page: data.current_page,
        max_page: data.max_page,
        records: data.records,
    })
}
