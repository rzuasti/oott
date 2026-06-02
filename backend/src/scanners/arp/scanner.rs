use super::finder;
use super::status;
use crate::db;
use crate::events;
use crate::model::device_events::DeviceEventScanner;
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
        status::set_running();

        // Find online devices via ARP
        let devices = finder::find(get_settings().networking.interface.clone()).await?;

        info!("Done with ARP probes");
        info!("Found {} online devices", devices.len());
        status::record_scan(devices.len() as u64);

        // Process found devices
        for device in devices.iter() {
            debug!("Online device found {}", device);

            // Read device from database
            let recorded_device_result = db::devices::read(device.mac_address.clone());

            match recorded_device_result {
                Some(recorded_device) => {
                    // If it exists update its last seen date
                    debug!(
                        "Device found in database {}. Updating to {}.",
                        recorded_device, device
                    );
                    db::devices::seen(
                        device.mac_address.clone(),
                        device.ipv4_address.clone(),
                        device.vendor.clone(),
                        device.device_type.clone(),
                        device.name.clone(),
                    )?;
                    events::trigger_existing_device(
                        recorded_device,
                        device.clone(),
                        DeviceEventScanner::Arp,
                    )
                    .ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
                None => {
                    // If it doesn't exist insert it
                    debug!(
                        "Device with MAC address {} not found in database. Inserting it.",
                        device.mac_address
                    );

                    db::devices::insert(device.clone())?;
                    events::trigger_new_device(device.clone(), DeviceEventScanner::Arp).ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
            };
        }

        let wait = Duration::from(get_settings().arp_scanner.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "Scan finished. Sleeping for {}",
            get_settings().arp_scanner.wait_between_scans
        );
        status::set_waiting(next_scan_at);
        sleep(wait).await;
    }
}
