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
pub struct SimpleNovelCover {
    pub title: String,
    pub aid: String,
}

