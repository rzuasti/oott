use crate::device_finders::Device;
use async_arp::{Client, ClientConfigBuilder, ClientSpinner, ProbeStatus, Result};
use std::io::Write;
use std::time::{Duration, Instant};

pub fn find() -> Vec<Device> {
    let mut devices = Vec::new();
    devices.push(Device {
        mac_address: String::from("mac1"),
    });
    devices.push(Device {
        mac_address: String::from("mac2"),
    });
    devices.push(Device {
        mac_address: String::from("mac3"),
    });

    devices
}
