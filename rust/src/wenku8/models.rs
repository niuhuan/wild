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