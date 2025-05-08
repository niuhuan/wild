use anyhow::{anyhow, Result};
use encoding_rs::GBK;
use flutter_rust_bridge::frb;
use once_cell::sync::Lazy;
use reqwest::{Client, cookie::Jar};
use scraper::{Html, Selector};
use std::sync::Arc;

use super::models::*;

pub struct Wenku8Client {
    pub client: Client,
    pub cookie_jar: Arc<Jar>,
}

impl Wenku8Client {
    pub async fn login(&self, username: &str, password: &str) -> Result<()> {
        let params = [
            ("username", username),
            ("password", password),
            ("usecookie", "3600"),
            ("action", "login"),
        ];

        let resp = self.client
            .post("https://www.wenku8.net/login.php")
            .form(&params)
            .send()
            .await?;

        if !resp.status().is_success() {
            return Err(anyhow!("Login failed: HTTP {}", resp.status()));
        }

        let body = decode_gbk(resp.bytes().await?)?;
        if body.contains("登录成功") {
            Ok(())
        } else {
            Err(anyhow!("Login failed: {}", body))
        }
    }

    pub async fn get_bookshelf(&self) -> Result<Vec<BookshelfItem>> {
        let resp = self.client
            .get("https://www.wenku8.net/modules/article/bookcase.php")
            .send()
            .await?;

        if !resp.status().is_success() {
            return Err(anyhow!("Failed to get bookshelf: HTTP {}", resp.status()));
        }

        let body = decode_gbk(resp.bytes().await?)?;
        let document = Html::parse_document(&body);
        
        let mut items = Vec::new();
        let row_selector = Selector::parse("tr").unwrap();
        let link_selector = Selector::parse("a").unwrap();

        for row in document.select(&row_selector).skip(1) {
            if let Some(first_link) = row.select(&link_selector).next() {
                let href = first_link.value().attr("href").unwrap_or("");
                if href.contains("/book/") {
                    let id = href.split('/').last().unwrap_or("").replace(".htm", "");
                    let title = first_link.text().collect::<String>();
                    
                    items.push(BookshelfItem {
                        novel: Novel {
                            id: id.clone(),
                            title,
                            author: String::new(),
                            cover_url: format!("http://img.wenku8.com/image/{}/{}/{}.jpg", 
                                            id.chars().next().unwrap_or('0'),
                                            id,
                                            id),
                            last_chapter: String::new(),
                            tags: Vec::new(),
                        },
                        last_read: String::new(),
                    });
                }
            }
        }

        Ok(items)
    }
}

fn decode_gbk(bytes: bytes::Bytes) -> Result<String> {
    let (cow, _, had_errors) = GBK.decode(&bytes);
    if had_errors {
        Err(anyhow!("Failed to decode GBK"))
    } else {
        Ok(cow.into_owned())
    }
}
