use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::notifications;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;
use chrono::Utc;
use log::{debug, info};
use tokio::time::{Duration, sleep};
use tokio_util::sync::CancellationToken;

pub async fn scan(shutdown: CancellationToken) -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().arp_scanner.enabled {
        info!("ARP scanner disabled in configuration; not starting");
        return Ok(());
    }

    loop {
        status::STATUS.set_running();

        // Find online devices via ARP, abandoning the probe immediately on shutdown rather than
        // waiting for every host to answer or time out.
        let devices = tokio::select! {
            _ = shutdown.cancelled() => break,
            result = finder::find(get_settings().networking.interface.clone()) => result?,
        };

        info!("Done with ARP probes");
        info!("Found {} online devices", devices.len());
        status::STATUS.record_scan(&devices);

        // Process found devices, accumulating every change so the whole scan emits one
        // consolidated notification per type (see notifications::notify) rather than one per device.
        let mut changes = Vec::new();
        for device in devices.iter() {
            debug!("Online device found {}", device);
            changes.extend(pipeline::record_sighting(
                device.clone(),
                DeviceEventScanner::Arp,
            ));
        }
        notifications::notify(changes);

        let wait = Duration::from(get_settings().arp_scanner.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "Scan finished. Sleeping for {}",
            get_settings().arp_scanner.wait_between_scans
        );
        status::STATUS.set_waiting(next_scan_at);
        // Wake early if shutdown is requested instead of sleeping out the whole interval.
        tokio::select! {
            _ = shutdown.cancelled() => break,
            _ = sleep(wait) => {}
        }
    }

    info!("ARP scanner shutting down");
    Ok(())
}
