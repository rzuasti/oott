use log::info;

use crate::mac_vendor_finder::MacVendorFinder;
mod config;
mod device_finders;
mod mac_vendor_finder;

#[tokio::main]
async fn main() {
    env_logger::init();
    info!("Starting up oott");

    let mut mac_vendor_finder = MacVendorFinder::new();

    let devices = device_finders::arp::find("eno1").await;

    info!("Done with ARP probes");
    info!("Found {} online devices", devices.iter().count());
    for device in devices.iter() {
        info!("Device found {}", device);
        let vendor_result = mac_vendor_finder.find(device.get_mac_prefix().as_str());
        match vendor_result {
            Some(vendor) => info!("Device vendor = {}", vendor),
            None => info!("Device vendor not found"),
        }
    }

    info!("Exiting");
}
