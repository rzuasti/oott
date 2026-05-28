use crate::db;
use crate::settings::get_settings;
use chrono::Utc;
use log::{error, info};
use tokio::time::{Duration, sleep};

pub async fn run() {
    loop {
        let window: std::time::Duration = get_settings().retention.window.into();
        let cutoff = match chrono::Duration::from_std(window) {
            Ok(d) => Utc::now() - d,
            Err(e) => {
                error!("Retention: invalid window duration: {}", e);
                sleep(Duration::from_secs(24 * 60 * 60)).await;
                continue;
            }
        };

        info!("Retention: purging records older than {}", cutoff);

        match db::device_events::purge_older_than(cutoff) {
            Ok(count) => info!("Retention: purged {} device event(s)", count),
            Err(e) => error!("Retention: error purging device events: {}", e),
        }

        match db::notifications::purge_older_than(cutoff) {
            Ok(count) => info!("Retention: purged {} notification(s)", count),
            Err(e) => error!("Retention: error purging notifications: {}", e),
        }

        sleep(Duration::from_secs(24 * 60 * 60)).await;
    }
}
