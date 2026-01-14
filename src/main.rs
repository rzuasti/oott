use log::{debug, info};
mod config;
mod device_finders;

#[tokio::main]
async fn main() {
    env_logger::init();
    info!("Starting up oott");

    let devices = device_finders::arp::find("eno1").await;

    info!("Done with ARP probes");
    for device in devices.iter() {
        debug!("Device found {}", device);
    }
    info!("Exiting");
}
