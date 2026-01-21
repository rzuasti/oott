use log::{debug, info};
use std::sync::{Arc, Mutex};

mod config;
mod db;
mod device_finders;
mod events;
mod mac_vendor_finder;

#[tokio::main]
async fn main() -> Result<(), String> {
    env_logger::init();
    info!("Starting up oott");

    // Get database connection - thread protected
    let db_conn = Arc::new(Mutex::new(db::init_db().unwrap()));

    // Find online devices via ARP
    let devices = device_finders::arp::find("eno1").await.unwrap();

    info!("Done with ARP probes");
    info!("Found {} online devices", devices.iter().count());

    // Process found devices
    for device in devices.iter() {
        debug!("Online device found {}", device);

        // Using just one connection for now, need to update if moved DB portion to multi-thread
        // need to change to a clone if we need multiple threads
        let db_conn_clone = Arc::clone(&db_conn);

        // Read device from database
        let recorded_device_result =
            db::devices::read(db_conn_clone.lock().unwrap(), device.mac_address.clone());

        match recorded_device_result {
            Some(recorded_device) => {
                // If it exists update its last seen date
                debug!(
                    "Device found in database {}. Updating to {}.",
                    recorded_device, device
                );
                db::devices::update(db_conn_clone.lock().unwrap(), device.clone())?;
                events::trigger_existing_device(recorded_device, device.clone());
            }
            None => {
                // If it doesn't exist insert it
                debug!(
                    "Device with MAC address {} not found in database. Inserting it.",
                    device.mac_address
                );

                db::devices::insert(db_conn_clone.lock().unwrap(), device.clone())?;
                events::trigger_new_device(device.clone());
            }
        };
    }

    info!("Exiting");

    Ok(())
}
