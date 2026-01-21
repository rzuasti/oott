use crate::device_finders::Device;
use log::info;

pub fn trigger_new_device(device: Device) {
    info!("Trigger - New device found: {}.", device);
}

pub fn trigger_existing_device(existing_device: Device, new_device: Device) {
    if existing_device.ipv4_address != new_device.ipv4_address {
        info!(
            "Trigger - Device with MAC {} changed IPv4 address from {} to {}.",
            existing_device.mac_address, existing_device.ipv4_address, new_device.ipv4_address
        );
    }
    if existing_device.vendor != new_device.vendor {
        info!(
            "Trigger - Device with MAC {} changed vendor from {} to {}.",
            existing_device.mac_address, existing_device.vendor, new_device.vendor
        );
    }
}
