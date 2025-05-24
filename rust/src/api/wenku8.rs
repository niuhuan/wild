use crate::database::entities::{
    CookieEntity, ReadingHistoryEntity, SignLogEntity,
    active::{
        novel_download,
        novel_download_volume,
        novel_download_chapter,
        DOWNLOAD_STATUS_NOT_DOWNLOAD,
    },
};
use crate::wenku8::{
    Bookcase, BookcaseItem, BookshelfItem, HomeBlock, Novel, NovelCover, NovelInfo, PageStats,
    TagGroup, UserDetail, Volume,
};
use crate::Result;
use crate::CLIENT;
use anyhow::Ok;
use sea_orm::{EntityTrait, ColumnTrait, QueryOrder};
use serde::{Deserialize, Serialize};
use std::time::Duration;

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

pub async fn logout() -> Result<()> {
    CookieEntity::delete_all().await?;
    Ok(())
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

pub async fn download_image(url: String) -> anyhow::Result<String> {
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
    progress_page: i32,
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
        progress_page,
        cover,
        author,
    )
    .await?;
    ReadingHistoryEntity::delete_old_records().await?;
    Ok(())
}

pub async fn delete_all_history() -> anyhow::Result<()> {
    ReadingHistoryEntity::delete_all().await?;
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
    pub progress: i32,      // 阅读进度 0-1
    pub progress_page: i32, // 阅读进度页码
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
            progress_page: history.progress_page,
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
            progress_page: history.progress_page,
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

pub async fn toplist(sort: String, page: i32) -> anyhow::Result<PageStatsNovelCover> {
    let key = format!("TOPLIST${}${}", sort, page);
    let data = crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.toplist(&sort, page).await }),
    )
    .await?;
    Ok(PageStatsNovelCover {
        current_page: data.current_page,
        max_page: data.max_page,
        records: data.records,
    })
}

pub async fn articlelist(fullflag: i32, page: i32) -> anyhow::Result<PageStatsNovelCover> {
    let key = format!("ARTICLELIST${}${}", fullflag, page);
    let data = crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.articlelist(fullflag, page).await }),
    )
    .await?;
    Ok(PageStatsNovelCover {
        current_page: data.current_page,
        max_page: data.max_page,
        records: data.records,
    })
}

pub async fn add_bookshelf(aid: String) -> anyhow::Result<()> {
    CLIENT.add_bookshelf(&aid).await
}

pub async fn delete_bookcase(bid: String) -> anyhow::Result<()> {
    CLIENT.delete_bookcase(&bid).await
}

pub async fn bookcase_list() -> anyhow::Result<Vec<Bookcase>> {
    CLIENT.bookcase_list().await
}

pub async fn book_in_case(case_id: String) -> anyhow::Result<Vec<BookcaseItem>> {
    CLIENT.book_in_case(&case_id).await
}

pub async fn move_bookcase(
    bid_list: Vec<String>,
    from_bookcase_id: String,
    to_bookcase_id: String,
) -> anyhow::Result<()> {
    CLIENT
        .move_bookcase(bid_list, from_bookcase_id, to_bookcase_id)
        .await
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SearchHistory {
    pub search_type: String,
    pub search_key: String,
    pub search_time: i64,
}

pub async fn search_histories() -> anyhow::Result<Vec<SearchHistory>> {
    let v = crate::database::entities::active::search_history::Entity::list_all().await?;
    Ok(v.into_iter()
        .map(|h| SearchHistory {
            search_type: h.search_type,
            search_key: h.search_key,
            search_time: h.search_time,
        })
        .collect())
}

pub async fn search(
    search_type: String,
    search_key: String,
    page: i32,
) -> anyhow::Result<PageStatsNovelCover> {
    crate::database::entities::active::search_history::Entity::save_or_update(
        search_type.clone(),
        search_key.clone(),
    )
    .await?;
    crate::database::entities::active::search_history::Entity::delete_old_records().await?;
    let key = format!("SEARCH${}${}${}", search_type, search_key, page);
    let data = crate::cache_first(
        key,
        Duration::from_secs(60 * 60),
        Box::pin(async move { CLIENT.search(&search_type, &search_key, page).await }),
    )
    .await?;
    Ok(PageStatsNovelCover {
        current_page: data.current_page,
        max_page: data.max_page,
        records: data.records,
    })
}

pub async fn auto_sign() -> anyhow::Result<bool> {
    if !SignLogEntity::is_signed_today().await? {
        CLIENT.sign().await?;
        SignLogEntity::sign().await?;
        SignLogEntity::delete_old_records().await?;
        Ok(true)
    } else {
        Ok(false)
    }
}

pub async fn download_novel(aid: String, cid_list: Vec<String>) -> anyhow::Result<()> {
    let novel_detail = novel_info(aid.clone()).await?;
    let volumes = novel_reader(aid.clone()).await?;
    let mut cid_list = cid_list;
    if cid_list.is_empty() {
        cid_list = volumes.iter().flat_map(|v| v.chapters.iter().map(|c| c.cid.clone())).collect();
    }

    // 1. 先处理章节信息
    for volume in &volumes {
        let volume_id = volume.id.clone();
        for chapter in &volume.chapters {
            let chapter_id = chapter.cid.clone();
            
            // 检查章节是否在下载列表中
            if cid_list.contains(&chapter_id) {
                // 检查章节是否已存在
                if let Some(existing_chapter) = novel_download_chapter::Entity::find_by_id(&chapter_id).await? {
                    // 如果章节已存在，跳过
                    continue;
                }

                // 章节不存在，插入新章节
                let chapter_title = chapter.title.clone();
                let chapter_url = chapter.url.clone();
                let chapter_idx = volume.chapters.iter().position(|c| c.cid == chapter.cid).unwrap_or(0) as i32;

                novel_download_chapter::Entity::upsert(
                    &chapter_id,
                    &chapter_title,
                    &chapter_url,
                    &aid,
                    &volume_id,
                    DOWNLOAD_STATUS_NOT_DOWNLOAD,
                    0, // 总图片数初始为0
                    chapter_idx,
                ).await?;
            }
        }
    }

    // 2. 处理卷信息
    for (volume_idx, volume) in volumes.iter().enumerate() {
        let volume_id = volume.id.clone();
        
        // 检查卷是否已存在
        if let Some(existing_volume) = novel_download_volume::Entity::find_by_id(&volume_id).await? {
            // 如果卷已存在，重置下载状态
            novel_download_volume::Entity::update_download_status(
                &volume_id,
                DOWNLOAD_STATUS_NOT_DOWNLOAD,
            ).await?;
        } else {
            // 卷不存在，插入新卷
            let volume_title = volume.title.clone();
            novel_download_volume::Entity::upsert(
                &volume_id,
                &aid,
                volume_idx as i32,
                &volume_title,
                DOWNLOAD_STATUS_NOT_DOWNLOAD,
            ).await?;
        }
    }

    // 3. 最后处理小说本体
    let novel_id = aid.clone();
    
    // 检查小说是否已存在
    if let Some(existing_novel) = novel_download::Entity::find_by_novel_id(&novel_id).await? {
        // 如果小说已存在，更新信息并重置下载状态
        let novel_name = novel_detail.title.clone();
        let cover_url = novel_detail.img_url.clone();
        let author = novel_detail.author.clone();
        let tags = novel_detail.tags.join(",");
        let introduce = novel_detail.introduce.clone();
        let trending = novel_detail.trending.clone();
        let is_animated = novel_detail.is_animated;
        let fin_update = novel_detail.fin_update.clone();
        let status = novel_detail.status.clone();
        let choose_chapter_count = cid_list.len() as i32;

        novel_download::Entity::upsert(
            &novel_id,
            &novel_name,
            DOWNLOAD_STATUS_NOT_DOWNLOAD,
            &cover_url,
            DOWNLOAD_STATUS_NOT_DOWNLOAD,
            &author,
            &tags,
            choose_chapter_count,
            0, // 已下载章节数重置为0
            &introduce,
            &trending,
            is_animated,
            &fin_update,
            &status,
        ).await?;
    } else {
        // 小说不存在，插入新小说
        let novel_name = novel_detail.title.clone();
        let cover_url = novel_detail.img_url.clone();
        let author = novel_detail.author.clone();
        let tags = novel_detail.tags.join(",");
        let introduce = novel_detail.introduce.clone();
        let trending = novel_detail.trending.clone();
        let is_animated = novel_detail.is_animated;
        let fin_update = novel_detail.fin_update.clone();
        let status = novel_detail.status.clone();
        let choose_chapter_count = cid_list.len() as i32;

        novel_download::Entity::upsert(
            &novel_id,
            &novel_name,
            DOWNLOAD_STATUS_NOT_DOWNLOAD,
            &cover_url,
            DOWNLOAD_STATUS_NOT_DOWNLOAD,
            &author,
            &tags,
            choose_chapter_count,
            0,
            &introduce,
            &trending,
            is_animated,
            &fin_update,
            &status,
        ).await?;
    }

    Ok(())
}

pub async fn all_downloads() -> anyhow::Result<Vec<NovelDownload>> {
    let downloads = novel_download::Entity::find()
        .order_by_desc(novel_download::Column::CreateTime)
        .all(&*crate::database::ACTIVE_DB_CONNECT.get().unwrap().lock().await)
        .await?;

    Ok(downloads.into_iter().map(|model| NovelDownload {
        novel_id: model.novel_id,
        novel_name: model.novel_name,
        download_status: model.download_status,
        cover_url: model.cover_url,
        cover_download_status: model.cover_download_status,
        author: model.author,
        tags: model.tags,
        choose_chapter_count: model.choose_chapter_count,
        download_chapter_count: model.download_chapter_count,
        create_time: model.create_time,
        download_time: model.download_time,
        introduce: model.introduce,
        trending: model.trending,
        is_animated: model.is_animated,
        fin_update: model.fin_update,
        status: model.status,
    }).collect())
}

pub async fn exists_download(novel_id: String) -> anyhow::Result<Option<ExistsDownload>> {
    // 1. 获取小说本体信息
    let novel = match novel_download::Entity::find_by_novel_id(&novel_id).await? {
        Some(novel) => novel,
        None => return Ok(None),
    };

    // 2. 获取卷信息
    let volumes = novel_download_volume::Entity::find_by_novel_id(&novel_id)
        .await?
        .into_iter()
        .map(|model| NovelDownloadVolume {
            id: model.id,
            novel_id: model.novel_id,
            volume_idx: model.volume_idx,
            title: model.title,
            download_status: model.download_status,
            create_time: model.create_time,
        })
        .collect();

    // 3. 获取章节信息
    let chapters = novel_download_chapter::Entity::find_by_novel_id(&novel_id)
        .await?
        .into_iter()
        .map(|model| NovelDownloadChapter {
            id: model.id,
            title: model.title,
            url: model.url,
            aid: model.aid,
            volume_id: model.volume_id,
            download_status: model.download_status,
            total_picture: model.total_picture,
            chapter_idx: model.chapter_idx,
        })
        .collect();

    // 4. 组装返回结果
    Ok(Some(ExistsDownload {
        novel_download: NovelDownload {
            novel_id: novel.novel_id,
            novel_name: novel.novel_name,
            download_status: novel.download_status,
            cover_url: novel.cover_url,
            cover_download_status: novel.cover_download_status,
            author: novel.author,
            tags: novel.tags,
            choose_chapter_count: novel.choose_chapter_count,
            download_chapter_count: novel.download_chapter_count,
            create_time: novel.create_time,
            download_time: novel.download_time,
            introduce: novel.introduce,
            trending: novel.trending,
            is_animated: novel.is_animated,
            fin_update: novel.fin_update,
            status: novel.status,
        },
        novel_download_volume: volumes,
        novel_download_chapter: chapters,
    }))
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExistsDownload {
    pub novel_download: NovelDownload,
    pub novel_download_volume: Vec<NovelDownloadVolume>,
    pub novel_download_chapter: Vec<NovelDownloadChapter>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct NovelDownload {
    pub novel_id: String,
    pub novel_name: String,
    pub download_status: i32,
    pub cover_url: String,
    pub cover_download_status: i32,
    pub author: String,
    pub tags: String,
    pub choose_chapter_count: i32,
    pub download_chapter_count: i32,
    pub create_time: i64,
    pub download_time: i64,
    pub introduce: String,
    pub trending: String,
    pub is_animated: bool,
    pub fin_update: String,
    pub status: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct NovelDownloadVolume {
    pub id: String,
    pub novel_id: String,
    pub volume_idx: i32,
    pub title: String,
    pub download_status: i32,
    pub create_time: i64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct NovelDownloadChapter {
    pub id: String,
    pub title: String,
    pub url: String,
    pub aid: String,
    pub volume_id: String,
    pub download_status: i32,
    pub total_picture: i32,
    pub chapter_idx: i32,
}
