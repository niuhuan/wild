use crate::Result;
use crate::CLIENT;
use crate::wenku8::BookshelfItem;

#[flutter_rust_bridge::frb]
pub async fn wenku8_login(username: String, password: String) -> Result<()> {
    CLIENT.login(&username, &password).await
}

#[flutter_rust_bridge::frb]
pub async fn wenku8_get_bookshelf() -> Result<Vec<BookshelfItem>> {
    CLIENT.get_bookshelf().await
} 