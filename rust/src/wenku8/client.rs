use anyhow::{anyhow, Result};
use encoding_rs::GBK;
use rand::Rng;
use reqwest::Client;
use scraper::{Html, Selector};

use super::models::*;

const API_HOST: &str = "https://www.wenku8.net";
const USER_AGENT: &str =
    "Dalvik/2.1.0 (Linux; U; Android 15; Android SDK built for arm64 Build/AE3A.240806.019)";

pub struct Wenku8Client {
    pub client: Client,
}

impl Wenku8Client {
    pub async fn checkcode(&self) -> Result<Vec<u8>> {
        let url = format!("{API_HOST}/checkcode.php");
        let params = [("random", rand::rng().random::<f64>().to_string())];
        let url = reqwest::Url::parse_with_params(url.as_str(), &params)?;
        let buffer = self.client.get(url).send().await?.bytes().await?.to_vec();
        Ok(buffer)
    }

    pub async fn login(&self, username: &str, password: &str, checkcode: &str) -> Result<()> {
        let url = format!("{API_HOST}/login.php");
        let params = [
            ("username", username),
            ("password", password),
            ("checkcode", checkcode),
            ("usecookie", "315360000"),
            ("action", "login"),
        ];

        let resp = self
            .client
            .post(url)
            .form(&params)
            .header("User-Agent", USER_AGENT)
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

    // /userdetail.php?charset=gbk
    pub async fn userdetail(&self) -> Result<UserDetail> {
        let url = format!("{API_HOST}/userdetail.php?charset=gbk");
        let response = self
            .client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Login failed: {}", response.status()));
        }

        let text = response.text().await?;
        Self::parse_user_detail(text.as_str())
    }

    pub(crate) fn parse_user_detail(text: &str) -> Result<UserDetail> {
        let mut user_detail = UserDetail::default();
        let html = Html::parse_document(text);
        let tr_selector = Selector::parse("tr[align=left]").unwrap();
        let td_odd_selector = Selector::parse("td.odd").unwrap();
        let td_even_selector = Selector::parse("td.even").unwrap();
        let tr_select = html.select(&tr_selector);
        for x in tr_select.into_iter() {
            let odd_select = x.select(&td_odd_selector).into_iter().next();
            let even_select = x.select(&td_even_selector).next();
            if let Some(odd) = odd_select {
                if let Some(even) = even_select {
                    let title = odd.inner_html();
                    let value = even.inner_html();
                    if title.trim().starts_with("用户ID：") {
                        user_detail.user_id = value.trim().to_string();
                    } else if title.trim().starts_with("用户名：") {
                        user_detail.username = value.trim().to_string();
                    } else if title.trim().starts_with("昵称：") {
                        user_detail.nickname =
                            value.trim().replace("(留空则用户名做昵称)", "").to_string();
                    } else if title.trim().starts_with("等级：") {
                        user_detail.level = value.trim().to_string();
                    } else if title.trim().starts_with("头衔：") {
                        user_detail.title = value.trim().to_string();
                    } else if title.trim().starts_with("性别：") {
                        user_detail.sex = value.trim().to_string();
                    } else if title.trim().starts_with("Email：") {
                        user_detail.email = regex::Regex::new("<a[^>]+>")?
                            .replace(value.trim(), "")
                            .replace("</a>", "")
                            .to_string();
                    } else if title.trim().starts_with("QQ：") {
                        user_detail.qq = value.trim().to_string();
                    } else if title.trim().starts_with("MSN：") {
                        user_detail.msn = regex::Regex::new("<a[^>]+>")?
                            .replace(value.trim(), "")
                            .replace("</a>", "")
                            .to_string();
                    } else if title.trim().starts_with("网站：") {
                        user_detail.web = regex::Regex::new("<a[^>]+>")?
                            .replace(value.trim(), "")
                            .replace("</a>", "")
                            .to_string();
                    } else if title.trim().starts_with("注册日期：") {
                        user_detail.register_date = value.trim().to_string();
                    } else if title.trim().starts_with("贡献值：") {
                        user_detail.contribute_point = value.trim().to_string();
                    } else if title.trim().starts_with("经验值：") {
                        user_detail.experience_value = value.trim().to_string();
                    } else if title.trim().starts_with("现有积分：") {
                        user_detail.holding_points = value.trim().to_string();
                    } else if title.trim().starts_with("最多好友数：") {
                        user_detail.quantity_of_friends = value.trim().to_string();
                    } else if title.trim().starts_with("信箱最多消息数：") {
                        user_detail.quantity_of_mail = value.trim().to_string();
                    } else if title.trim().starts_with("书架最大收藏量：") {
                        user_detail.quantity_of_collection = value.trim().to_string();
                    } else if title.trim().starts_with("每天允许推荐次数：") {
                        user_detail.quantity_of_recommend_daily = value.trim().to_string();
                    } else if title.trim().starts_with("用户签名：") {
                        user_detail.personalized_signature = value.trim().to_string();
                    } else if title.trim().starts_with("个人简介：") {
                        user_detail.personalized_description = value.trim().to_string();
                    }
                }
            }
        }
        Ok(user_detail)
    }

    pub async fn get_bookshelf(&self) -> Result<Vec<BookshelfItem>> {
        let resp = self
            .client
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
                            cover_url: format!(
                                "http://img.wenku8.com/image/{}/{}/{}.jpg",
                                id.chars().next().unwrap_or('0'),
                                id,
                                id
                            ),
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
