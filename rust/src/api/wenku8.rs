use crate::wenku8::{BookshelfItem, HomeBlock, NovelInfo, UserDetail, Volume};
use crate::Result;
use crate::CLIENT;
use crate::database;
use std::path::Path;

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
    CLIENT.index().await
}

pub async fn download_image(url: String) -> anyhow::Result<Vec<u8>> {
    crate::get_cached_image(url).await
}

pub async fn novel_info(aid: String) -> anyhow::Result<NovelInfo> {
    CLIENT.novel_info(&aid).await
}

pub async fn novel_reader(aid: String) -> anyhow::Result<Vec<Volume>> {
    CLIENT.novel_reader(&aid).await
}
