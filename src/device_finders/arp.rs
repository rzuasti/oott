use crate::device_finders::Device;

pub fn find() -> Vec<Device> {
    //let devices = helper_async_arp::execute_probe(&String::from("eno1"));

    let mut devices = Vec::new();
    devices.push(Device {mac_address: String::from("mac"), ipv4_address: String::from("ip")});
    devices
}
