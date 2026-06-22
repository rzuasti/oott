use crate::db;
use crate::settings::get_settings;
use chrono::Utc;
use log::{error, info};
use tokio::time::{Duration, sleep};
use tokio_util::sync::CancellationToken;

const SWEEP_INTERVAL: Duration = Duration::from_secs(24 * 60 * 60);

pub async fn run(shutdown: CancellationToken) {
    loop {
        let window: std::time::Duration = get_settings().retention.window.into();
        let cutoff = match chrono::Duration::from_std(window) {
            Ok(d) => Utc::now() - d,
            Err(e) => {
                error!("Retention: invalid window duration: {}", e);
                if !sleep_unless_shutdown(SWEEP_INTERVAL, &shutdown).await {
                    break;
                }
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

        if !sleep_unless_shutdown(SWEEP_INTERVAL, &shutdown).await {
            break;
        }
    }

    info!("Retention cleaner shutting down");
}

/// Sleep for `duration`, returning early if shutdown is requested. Returns `true` if the full
/// duration elapsed (keep looping) and `false` if shutdown interrupted it (stop the loop).
async fn sleep_unless_shutdown(duration: Duration, shutdown: &CancellationToken) -> bool {
    tokio::select! {
        _ = shutdown.cancelled() => false,
        _ = sleep(duration) => true,
    }
}
