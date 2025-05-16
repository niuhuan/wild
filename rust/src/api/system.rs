use crate::local::join_paths;
use crate::Result;

pub fn desktop_root() -> Result<String> {
    #[cfg(target_os = "windows")]
    {
        use anyhow::Context;
        Ok(join_paths(vec![
            std::env::current_exe()?
                .parent()
                .with_context(|| "error")?
                .to_str()
                .with_context(|| "error")?,
            "data",
        ]))
    }
    #[cfg(target_os = "macos")]
    {
        use anyhow::Context;
        let home = std::env::var_os("HOME")
            .with_context(|| "error")?
            .to_str()
            .with_context(|| "error")?
            .to_string();
        Ok(join_paths(vec![
            home.as_str(),
            "Library",
            "Application Support",
            "opensource",
            "wild",
        ]))
    }
    #[cfg(target_os = "linux")]
    {
        use anyhow::Context;
        let home = std::env::var_os("HOME")
            .with_context(|| "error")?
            .to_str()
            .with_context(|| "error")?
            .to_string();
        Ok(join_paths(vec![home.as_str(), ".opensource", "wild"]))
    }
    #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
    panic!("未支持的平台")
}

pub async fn init(root: String) -> Result<()> {
    // 调用全局初始化函数
    crate::init(root).await?;
    Ok(())
}
