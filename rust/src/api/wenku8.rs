use crate::wenku8::{BookshelfItem, UserDetail};
use crate::Result;
use crate::CLIENT;

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
