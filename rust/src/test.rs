use crate::wenku8::Wenku8Client;
use crate::CLIENT;

fn set_logger() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
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
