use log::{debug, info};

mod config;
mod db;
mod device_finders;
mod mac_vendor_finder;

#[tokio::main]
async fn main() {
    env_logger::init();
    info!("Starting up oott");

    let db_conn = db::init_db();

    let devices = device_finders::arp::find("eno1").await.unwrap();

    info!("Done with ARP probes");
    info!("Found {} online devices", devices.iter().count());

    // mac_vendor_finder.populate_vendors(&devices);

    for device in devices.iter() {
        debug!("Device found {}", device);
    }

    info!("Exiting");
}
