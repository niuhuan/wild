use super::models::*;
use anyhow::{anyhow, Result};
use base64::Engine;
use encoding_rs::GBK;
use rand::Rng;
use reqwest::Client;
use scraper::Node::Element;
use scraper::{ElementRef, Html, Selector};
use std::slice::SliceIndex;

const API_HOST: &str = "https://www.wenku8.net";
const APP_HOST: &str = "http://app.wenku8.com";
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

        let text = response.bytes().await?;
        let text = decode_gbk(text)?;
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

    pub async fn novel_info(&self, aid: &str) -> Result<NovelInfo> {
        let url = format!("{API_HOST}/modules/article/articleinfo.php?id={aid}&charset=gbk");
        let response = self
            .client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Failed to get novel info: {}", response.status()));
        }

        let text = response.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_novel_info(text.as_str())
    }

    pub(crate) fn parse_novel_info(text: &str) -> Result<NovelInfo> {
        let mut novel_info = NovelInfo::default();
        //
        let content_selector = Selector::parse("#content").unwrap();
        let table_selector = Selector::parse("table").unwrap();
        let span_selector = Selector::parse("span").unwrap();
        let b_selector = Selector::parse("b").unwrap();
        let tr_selector = Selector::parse("tr").unwrap();
        let td_selector = Selector::parse("td").unwrap();
        let img_selector = Selector::parse("img").unwrap();
        //
        let html = Html::parse_document(text);
        let content = html
            .select(&content_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find content"))?;
        let table = content
            .select(&table_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find table"))?;

        /*

        val title = table.select("span").eq(0).select("b").eq(0).text()
        val author = table.select("tr").eq(2).select("td").eq(1).text().substring(5)
        val status = table.select("tr").eq(2).select("td").eq(2).text().substring(5)
         */

        let title = table
            .select(&span_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find title"))?
            .select(&b_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find title"))?
            .text()
            .collect::<String>();
        novel_info.title = title;

        let author = table
            .select(&tr_selector)
            .nth(2)
            .ok_or_else(|| anyhow!("Failed to find author"))?
            .select(&td_selector)
            .nth(1)
            .ok_or_else(|| anyhow!("Failed to find author"))?
            .text()
            .collect::<String>()
            .chars()
            .skip(5)
            .collect();
        novel_info.author = author;

        let status = table
            .select(&tr_selector)
            .nth(2)
            .ok_or_else(|| anyhow!("Failed to find status"))?
            .select(&td_selector)
            .nth(2)
            .ok_or_else(|| anyhow!("Failed to find status"))?
            .text()
            .collect::<String>()
            .chars()
            .skip(5)
            .collect();
        novel_info.status = status;

        let fin_update = if let Some(tr) = table.select(&tr_selector).nth(2) {
            if let Some(td) = tr.select(&td_selector).nth(3) {
                let text = td.text().collect::<String>();
                text.chars().skip(5).collect::<String>()
            } else {
                "".to_string()
            }
        } else {
            "".to_string()
        };
        novel_info.fin_update = fin_update;

        let mut img_url = content
            .select(&img_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find img_url"))?
            .value()
            .attr("src")
            .ok_or_else(|| anyhow!("Failed to find img_url"))?
            .to_string();
        novel_info.img_url = img_url;

        let introduce = content
            .select(&table_selector)
            .nth(2)
            .ok_or_else(|| anyhow!("Failed to find introduce"))?
            .select(&td_selector)
            .nth(1)
            .ok_or_else(|| anyhow!("Failed to find introduce"))?
            .select(&span_selector)
            .nth(5)
            .ok_or_else(|| anyhow!("Failed to find introduce"))?
            .html();
        novel_info.introduce = introduce;

        let tag = content
            .select(&table_selector)
            .nth(2)
            .ok_or_else(|| anyhow!("Failed to find tag"))?
            .select(&td_selector)
            .nth(1)
            .ok_or_else(|| anyhow!("Failed to find tag"))?
            .select(&span_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find tag"))?
            .text()
            .collect::<String>();
        let tag = tag
            .chars()
            .skip(7)
            .collect::<String>()
            .split(" ")
            .map(|e| e.to_string())
            .collect();
        novel_info.tags = tag;

        if let Some(table) = content.select(&table_selector).nth(2) {
            if let Some(td) = table.select(&td_selector).nth(1) {
                if let Some(_) = td.select(&span_selector).nth(1) {
                    novel_info.is_animated = true;
                }
            }
        }

        Ok(novel_info)
    }

    pub async fn index(&self) -> Result<Vec<HomeBlock>> {
        let resp = self
            .client
            .get(format!("{API_HOST}/index.php?charset=gbk"))
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;

        if !resp.status().is_success() {
            return Err(anyhow!("Failed to get index: HTTP {}", resp.status()));
        }

        let text = resp.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_index(text.as_str())
    }

    pub(crate) fn parse_index(text: &str) -> Result<Vec<HomeBlock>> {
        let mut home_blocks = Vec::new();

        let centers_selector = Selector::parse("#centers").unwrap();
        let main_div_selector = Selector::parse("div.main").unwrap();

        let html = Html::parse_document(text);
        let center = html
            .select(&centers_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find center"))?;
        Self::find_block(&mut home_blocks, center)?;

        let block_selector = Selector::parse(".block").unwrap();
        let blocktitle_selector = Selector::parse(".blocktitle").unwrap();
        let img_selector = Selector::parse("div>a>img").unwrap();

        for main_div in html.select(&main_div_selector).skip(5).take(2).into_iter() {
            for block in main_div.select(&block_selector) {
                let block_title = block
                    .select(&blocktitle_selector)
                    .next()
                    .ok_or_else(|| anyhow!("Failed to find block title"))?
                    .text()
                    .collect::<String>();
                let mut novel_covers = Vec::new();
                for img in block.select(&img_selector) {
                    let parent = img
                        .parent()
                        .ok_or_else(|| anyhow!("Failed to find block title"))?;
                    if let Element(e) = &parent.value() {
                        if e.name.local.to_string().eq("a") {
                            let parent = ElementRef::wrap(parent).unwrap();
                            let title = parent
                                .value()
                                .attr("title")
                                .ok_or_else(|| anyhow!("Failed to find title"))?
                                .to_string();
                            let mut img = img
                                .value()
                                .attr("src")
                                .ok_or_else(|| anyhow!("Failed to find img"))?
                                .to_string();
                            let detail_url = parent
                                .value()
                                .attr("href")
                                .ok_or_else(|| anyhow!("Failed to find detail_url"))?
                                .to_string();
                            let aid = detail_url
                                .split('/')
                                .last()
                                .ok_or_else(|| anyhow!("Failed to find aid"))?
                                .replace(".htm", "");
                            novel_covers.push(NovelCover {
                                title: title.clone(),
                                img: img.clone(),
                                detail_url: detail_url.clone(),
                                aid: aid.clone(),
                            });
                        }
                    }
                }
                home_blocks.push(HomeBlock {
                    title: block_title,
                    list: novel_covers,
                })
            }
        }

        Ok(home_blocks)
    }

    fn find_block(home_blocks: &mut Vec<HomeBlock>, element_ref: ElementRef) -> Result<()> {
        let block_selector = Selector::parse(".block").unwrap();
        let blocktitle_selector = Selector::parse(".blocktitle").unwrap();
        let c_div_selector = Selector::parse(".blockcontent>div>div").unwrap();
        let a_selector = Selector::parse("a").unwrap();
        let img_selector = Selector::parse("img").unwrap();
        for block in element_ref
            .select(&block_selector)
            .skip(1)
            .take(3)
            .into_iter()
        {
            let block_title = block
                .select(&blocktitle_selector)
                .next()
                .ok_or_else(|| anyhow!("Failed to find block title"))?
                .text()
                .collect::<String>();
            let mut novel_covers = Vec::new();
            for j in block.select(&c_div_selector) {
                let title = j
                    .select(&a_selector)
                    .nth(1)
                    .ok_or_else(|| anyhow!("Failed to find title"))?
                    .text()
                    .collect::<String>();
                let mut img = j
                    .select(&img_selector)
                    .next()
                    .ok_or_else(|| anyhow!("Failed to find img"))?
                    .value()
                    .attr("src")
                    .ok_or_else(|| anyhow!("Failed to find img"))?
                    .to_string();
                let url = j
                    .select(&a_selector)
                    .next()
                    .ok_or_else(|| anyhow!("Failed to find url"))?
                    .value()
                    .attr("href")
                    .ok_or_else(|| anyhow!("Failed to find url"))?
                    .to_string();
                let aid = url
                    .split('/')
                    .last()
                    .ok_or_else(|| anyhow!("Failed to find aid"))?
                    .replace(".htm", "");
                novel_covers.push(NovelCover {
                    title: title.clone(),
                    img: img.clone(),
                    detail_url: url.clone(),
                    aid: aid.clone(),
                });
            }
            home_blocks.push(HomeBlock {
                title: block_title,
                list: novel_covers,
            })
        }
        Ok(())
    }

    pub async fn tags(&self) -> Result<Vec<TagGroup>> {
        let resp = self
            .client
            .get(format!("{API_HOST}/modules/article/tags.php?charset=gbk"))
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;

        if !resp.status().is_success() {
            return Err(anyhow!("Failed to get tags: HTTP {}", resp.status()));
        }

        let text = resp.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_tags(text.as_str())
    }

    pub(crate) fn parse_tags(text: &str) -> Result<Vec<TagGroup>> {
        let mut tag_groups = Vec::new();
        let html = Html::parse_document(text);

        let ul_selector = Selector::parse("ul.ultops").unwrap();
        let li_selector = Selector::parse("li").unwrap();
        let a_selector = Selector::parse("a").unwrap();

        let ul_elements = html.select(&ul_selector);
        let mut group_name = "".to_string();
        let mut tags = Vec::<String>::new();
        for ul in ul_elements {
            let li = ul.select(&li_selector);
            for li in li {
                if li.inner_html().ends_with("Tags：") {
                    if !group_name.is_empty() {
                        tag_groups.push(TagGroup {
                            title: group_name.clone(),
                            tags: tags.clone(),
                        });
                    }
                    group_name = li.inner_html().replace("Tags：", "")
                        .replace("系", "")
                        .replace("属性", "")
                        .replace("类", "");
                    tags.clear();
                } else {
                    let a = li.select(&a_selector);
                    for a in a {
                        let tag = a.text().collect::<String>();
                        tags.push(tag.clone());
                    }
                }
            }
        }

        Ok(tag_groups)
    }

    ///
    /// v  "0"=按更新查看 , "1"=按热门查看 , "2"=只看已完结 , "3"=只看动画化
    ///
    pub async fn tag_page(
        &self,
        tag: &str,
        v: &str,
        page_number: i32,
    ) -> Result<PageStats<NovelCover>> {
        let url = format!(
            "{}/modules/article/tags.php?t={}&v={}&page={}&charset=gbk",
            API_HOST, gbk_url_encode(tag), v, page_number,
        );
        let response = self
            .client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Failed to get tag page: {}", response.status()));
        }

        let text = response.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_tag_page(text.as_str())
    }

    pub(crate) fn parse_tag_page(text: &str) -> Result<PageStats<NovelCover>> {
        let mut novels = Vec::new();

        let html = Html::parse_document(text);

        let gird_selector = Selector::parse("table.grid tr td>div").unwrap();
        let img_selector = Selector::parse("div>a>img").unwrap();
        let page_stats_selector = Selector::parse("em#pagestats").unwrap();
        let mut current_page = 0;
        let mut max_page = 0;

        for block in html.select(&gird_selector) {
            for img in block.select(&img_selector) {
                let parent = img
                    .parent()
                    .ok_or_else(|| anyhow!("Failed to find block title"))?;
                if let Element(e) = &parent.value() {
                    if e.name.local.to_string().eq("a") {
                        let parent = ElementRef::wrap(parent).unwrap();
                        let title = parent
                            .value()
                            .attr("title")
                            .ok_or_else(|| anyhow!("Failed to find title"))?
                            .to_string();
                        let mut img = img
                            .value()
                            .attr("src")
                            .ok_or_else(|| anyhow!("Failed to find img"))?
                            .to_string();
                        let detail_url = parent
                            .value()
                            .attr("href")
                            .ok_or_else(|| anyhow!("Failed to find detail_url"))?
                            .to_string();
                        let aid = detail_url
                            .split('/')
                            .last()
                            .ok_or_else(|| anyhow!("Failed to find aid"))?
                            .replace(".htm", "");
                        novels.push(NovelCover {
                            title: title.clone(),
                            img: img.clone(),
                            detail_url: detail_url.clone(),
                            aid: aid.clone(),
                        });
                    }
                }
            }
        }

        for page_stats in html.select(&page_stats_selector) {
            let text = page_stats.text().collect::<String>();
            let split = text.split("/").collect::<Vec<&str>>();
            if let Some(&a) = split.get(0) {
                if let Ok(num) = a.trim().parse::<i32>() {
                    current_page = num;
                }
            }
            if let Some(&a) = split.get(1) {
                if let Ok(num) = a.trim().parse::<i32>() {
                    max_page = num;
                }
            }
        }

        Ok(PageStats {
            current_page,
            max_page,
            records: novels,
        })
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

    pub async fn download_image(&self, url: &str) -> Result<Vec<u8>> {
        let response = self.client.get(url)
            .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
            .header("Referer", "https://www.wenku8.net/")
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!("Failed to download image: {}", response.status()));
        }

        Ok(response.bytes().await?.to_vec())
    }

    pub(crate) fn parse_reader(text: &str) -> Result<Vec<Volume>> {
        let mut volumes = Vec::new();
        let html = Html::parse_document(text);
        let table_selector = Selector::parse("table.css").unwrap();
        let tr_selector = Selector::parse("tr").unwrap();
        let vcss_td_selector = Selector::parse("td.vcss").unwrap();
        let ccss_td_a_selector = Selector::parse("td.ccss>a").unwrap();

        let mut vid = "".to_string();
        let mut vtitle = "".to_string();
        let mut chapters = Vec::<Chapter>::new();

        let table = html
            .select(&table_selector)
            .next()
            .ok_or_else(|| anyhow!("Failed to find table"))?;

        for tr in table.select(&tr_selector) {
            if let Some(td) = tr.select(&vcss_td_selector).next() {
                if !"".eq(vid.as_str()) {
                    volumes.push(Volume {
                        id: vid,
                        title: vtitle,
                        chapters,
                    });
                }
                vid = td.value().attr("vid").unwrap_or("").to_string();
                vtitle = td.text().collect();
                chapters = vec![];
            } else {
                for a in tr.select(&ccss_td_a_selector) {
                    let title = a.text().collect::<String>();
                    let url = a.value().attr("href").unwrap_or("");
                    let url = url::Url::parse(url)?;
                    let pairs = url.query_pairs();
                    let pairs_map = pairs
                        .into_owned()
                        .collect::<std::collections::HashMap<_, _>>();
                    let cid = pairs_map
                        .get("cid")
                        .ok_or_else(|| anyhow!("Failed to find cid"))?
                        .to_string();
                    let aid = pairs_map
                        .get("aid")
                        .ok_or_else(|| anyhow!("Failed to find aid"))?
                        .to_string();
                    chapters.push(Chapter {
                        title,
                        url: url.to_string(),
                        cid,
                        aid,
                    });
                }
            }
        }
        if !"".eq(vid.as_str()) {
            volumes.push(Volume {
                id: vid,
                title: vtitle,
                chapters,
            });
        }

        Ok(volumes)
    }

    pub async fn novel_reader(&self, aid: &str) -> Result<Vec<Volume>> {
        let url = format!("{API_HOST}/modules/article/reader.php?aid={aid}&charset=gbk");
        let response = self
            .client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Failed to get novel reader: {}", response.status()));
        }

        let text = response.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_reader(text.as_str())
    }

    pub async fn c_content(&self, aid: &str, cid: &str) -> Result<String> {
        let url = format!("{APP_HOST}/android.php");
        let params = [
            (
                "request",
                base64::prelude::BASE64_STANDARD
                    .encode(format!("action=book&do=text&aid={aid}&cid={cid}&t=0").as_bytes()),
            ),
            ("appver", "1.18".to_string()),
            ("timetoken", chrono::Utc::now().timestamp().to_string()),
        ];
        let response = self
            .client
            .post(url)
            .header("User-Agent", USER_AGENT)
            .form(&params)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Failed to get novel reader: {}", response.status()));
        }
        let text = response.text().await?;
        Ok(text)
    }
    
    pub async fn toplist(&self, sort: &str, page: i32) -> Result<PageStats<NovelCover>> {
        let url = format!(
            "{API_HOST}/modules/article/toplist.php?sort={sort}&page={page}&charset=gbk"
        );
        let response = self
            .client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await?;
        if !response.status().is_success() {
            return Err(anyhow!("Failed to get toplist: {}", response.status()));
        }

        let text = response.bytes().await?;
        let text = decode_gbk(text)?;
        Self::parse_toplist(text.as_str())
    }

    pub(crate) fn parse_toplist(text: &str) -> Result<PageStats<NovelCover>> {
        Self::parse_tag_page(text)
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

fn gbk_url_encode(text: &str) -> String {
    let gbk_bytes = GBK
        .encode(text)
        .0
        .into_iter()
        .map(|b| *b)
        .collect::<Vec<u8>>();
    let mut encoded = String::new();
    for byte in gbk_bytes {
        if byte.is_ascii_alphanumeric() || byte == b'_' {
            encoded.push(byte as char);
        } else {
            encoded.push_str(&format!("%{:02X}", byte));
        }
    }
    encoded
}
