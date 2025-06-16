use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Novel {
    pub id: String,
    pub title: String,
    pub author: String,
    pub cover_url: String,
    pub last_chapter: String,
    pub tags: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BookshelfItem {
    pub novel: Novel,
    pub last_read: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct UserDetail {
    pub username: String,
    pub user_id: String,
    pub nickname: String,
    pub level: String,
    pub title: String,
    pub sex: String,
    pub email: String,
    pub qq: String,
    pub msn: String,
    pub web: String,
    pub register_date: String,
    pub contribute_point: String,
    pub experience_value: String,
    pub holding_points: String,
    pub quantity_of_friends: String,
    pub quantity_of_mail: String,
    pub quantity_of_collection: String,
    pub quantity_of_recommend_daily: String,
    pub personalized_signature: String,
    pub personalized_description: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct NovelInfo {
    pub title: String,
    pub author: String,
    pub status: String,
    pub fin_update: String,
    pub img_url: String,
    pub introduce: String,
    pub tags: Vec<String>,
    pub heat: String,
    pub trending: String,
    pub is_animated: bool,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct HomeBlock {
    pub title: String,
    pub list: Vec<NovelCover>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct NovelCover {
    pub title: String,
    pub img: String,
    pub detail_url: String,
    pub aid: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct PageStats<T> {
    pub current_page: i32,
    pub max_page: i32,
    pub records: Vec<T>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct SimpleNovelCover {
    pub title: String,
    pub aid: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Chapter {
    pub title: String,
    pub url: String,
    pub cid: String,
    pub aid: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Volume {
    pub id: String,
    pub title: String,
    pub chapters: Vec<Chapter>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct NovelDetail {
    pub aid: String,
    pub title: String,
    pub author: String,
    pub cover_url: String,
    pub last_chapter: String,
    pub tags: Vec<String>,
    pub status: String,
    pub fin_update: String,
    pub img_url: String,
    pub introduce: String,
    pub heat: String,
    pub trending: String,
    pub is_animated: bool,
    pub volumes: Vec<Volume>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct TagGroup {
    pub title: String,
    pub tags: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Bookcase {
    pub id: String,
    pub title: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct BookcaseItem {
    pub aid: String,
    pub bid: String,
    pub title: String,
    pub author: String,
    pub cid: String,
    pub chapter_name: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct BookcaseDto {
    pub items: Vec<BookcaseItem>,
    pub tip: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct Review {
    pub rid: String,
    pub content: String,
    pub reply_count: i32,
    pub uid: String,
    pub uname: String,
    pub time: String,
}
