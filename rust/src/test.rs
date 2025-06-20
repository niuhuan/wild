use crate::wenku8::Wenku8Client;
use crate::CLIENT;

fn set_logger() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_test_writer()
        .init();
}

async fn init_context() -> anyhow::Result<()> {
    set_logger();
    crate::init("target/test_data".to_string()).await?;
    Ok(())
}

#[tokio::test]
async fn test_init() -> anyhow::Result<()> {
    init_context().await?;
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_cookie_store() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT
        .client
        .get("https://baidu.com/")
        .header("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36")
        .send()
        .await?;
    let text = response.text().await?;
    println!("{}", text);
    Ok(())
}

#[test]
fn test_parse_user_detail() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/ud.txt")?;
    let ud = Wenku8Client::parse_user_detail(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&ud)?);
    Ok(())
}

#[test]
fn test_parse_novel_info() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/ti.txt")?;
    let info = Wenku8Client::parse_novel_info(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&info)?);
    let text = std::fs::read_to_string("target/ti2.txt")?;
    let info = Wenku8Client::parse_novel_info(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&info)?);
    Ok(())
}

#[test]
fn test_parse_index() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/idx.txt")?;
    let index = Wenku8Client::parse_index(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&index)?);
    Ok(())
}

#[test]
fn test_parse_reader() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/rd.txt")?;
    let reader = Wenku8Client::parse_reader(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&reader)?);
    Ok(())
}

#[test]
fn test_parse_tags() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/tags.txt")?;
    let tags = Wenku8Client::parse_tags(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_tag_page() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/tag_page.txt")?;
    let tags = Wenku8Client::parse_tag_page(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_toplist() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/toplist.txt")?;
    let tags = Wenku8Client::parse_toplist(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_articlelist() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/articlelist.txt")?;
    let tags = Wenku8Client::parse_articlelist(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_bookcase_list() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/bookcase_list.txt")?;
    let tags = Wenku8Client::parse_bookcase_list(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_book_in_case() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/book_in_case.txt")?;
    let tags = Wenku8Client::parse_book_in_case(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_reviews() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/rv.txt")?;
    let tags = Wenku8Client::parse_reviews(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn parse_search() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/search.txt")?;
    let tags = Wenku8Client::parse_search(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_novel_info() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.novel_info("3").await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_add_bookshelf() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.add_bookshelf("1143").await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_c_content() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.c_content("3103", "128331").await?;
    println!("response : {}", response);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_tag_page() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.tag_page("治愈", "1", 1).await?;
    println!("{}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_reviews() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.reviews("2441", 1).await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

1