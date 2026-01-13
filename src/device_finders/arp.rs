use crate::device_finders::Device;

mod helper_async_arp;

pub fn find() -> Vec<Device> {
    let devices = helper_async_arp::execute_probe(&String::from("eno1"));

    devices
}
