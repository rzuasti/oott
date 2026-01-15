use log::{debug, info};
mod config;
mod device_finders;

#[tokio::main]
async fn main() {
    env_logger::init();
    info!("Starting up oott");

    let devices = device_finders::arp::find("wlp1s0").await;

    info!("Done with ARP probes");
    info!("Found {} online devices", devices.iter().count());
    for device in devices.iter() {
        info!("Device found {}", device);
    }
    info!("Exiting");
}
