use crate::database::entities::PropertyEntity;

pub async fn load_property(key: String) -> anyhow::Result<String> {
    Ok(PropertyEntity::get_value(key.as_str())
        .await?
        .unwrap_or_default())
}

pub async fn save_property(key: String, value: String) -> anyhow::Result<()> {
    PropertyEntity::set_value(key, value).await?;
    Ok(())
}
