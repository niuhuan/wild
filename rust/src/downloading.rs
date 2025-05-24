use tokio::task::spawn;
use crate::Result;

pub async fn start_downloading() -> Result<()> {
    spawn(async move {
        // TODO: Implement download manager
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
        }
    });
    Ok(())
}
