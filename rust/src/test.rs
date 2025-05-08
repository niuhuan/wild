fn set_logger() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_test_writer()
        .init();
}

#[tokio::test]
async fn test_init() -> anyhow::Result<()> {
    set_logger();
    crate::init("test_data".to_string()).await?;
    Ok(())
}
