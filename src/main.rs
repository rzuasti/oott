mod device_finders;

fn main() {
    let devices = device_finders::arp::find();

    for device in devices.iter() {
        println!("{}", device);
    }
}
