use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;
use chrono::Utc;
use log::{debug, info};
use tokio::time::{Duration, sleep};

pub async fn scan() -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().arp_scanner.enabled {
        info!("ARP scanner disabled in configuration; not starting");
        return Ok(());
    }

    loop {
        status::STATUS.set_running();

        // Find online devices via ARP
        let devices = finder::find(get_settings().networking.interface.clone()).await?;

        info!("Done with ARP probes");
        info!("Found {} online devices", devices.len());
        status::STATUS.record_scan(&devices);

        // Process found devices
        for device in devices.iter() {
            debug!("Online device found {}", device);
            pipeline::record_sighting(device.clone(), DeviceEventScanner::Arp);
        }

        let wait = Duration::from(get_settings().arp_scanner.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "Scan finished. Sleeping for {}",
            get_settings().arp_scanner.wait_between_scans
        );
        status::STATUS.set_waiting(next_scan_at);
        sleep(wait).await;
    }
}
