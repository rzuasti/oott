mod device_finders;

#[tokio::main]
async fn main() {
    let devices = device_finders::arp::find("eno1").await;

    for device in devices.iter() {
        println!("{}", device);
    }
}
