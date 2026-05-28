use crate::arp_scanner_status;
use crate::db;
use crate::device_finders;
use crate::events;
use crate::settings::get_settings;
use chrono::Utc;
use log::{debug, info};
use tokio::time::{Duration, sleep};

pub async fn scan() -> Result<(), Box<dyn std::error::Error>> {
    loop {
        arp_scanner_status::set_running();

        // Find online devices via ARP
        let devices =
            device_finders::arp::find(get_settings().networking.interface.to_string()).await?;

        info!("Done with ARP probes");
        info!("Found {} online devices", devices.len());

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
                    db::devices::update(device.clone())?;
                    events::trigger_existing_device(recorded_device, device.clone()).ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
                None => {
                    // If it doesn't exist insert it
                    debug!(
                        "Device with MAC address {} not found in database. Inserting it.",
                        device.mac_address
                    );

                    db::devices::insert(device.clone())?;
                    events::trigger_new_device(device.clone()).ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
            };
        }

        let wait = Duration::from(get_settings().arp_scanner.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "Scan finished. Sleeping for {}",
            get_settings().arp_scanner.wait_between_scans
        );
        arp_scanner_status::set_waiting(next_scan_at);
        sleep(wait).await;
    }
}
