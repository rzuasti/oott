use log::{debug, error};

use crate::db;
use crate::events;
use crate::model::device_events::DeviceEventScanner;
use crate::model::devices::Device;

/// Persist a device sighting and emit the matching event/notification, feeding every scanner
/// (ARP, mDNS, SSDP, DHCP, SNMP) through one code path.
///
/// When the device is already known, the sighting is reconciled with the stored record:
/// - a previously stored hostname is kept rather than overwritten by this sighting's name;
/// - a known IP address is kept when this sighting carries none (an empty string), so a DHCP
///   DISCOVER (which has no assigned IP) never clobbers a good address.
///
/// Errors are logged and swallowed: a scan/listen loop must never stop because a single sighting
/// failed to persist or a notification could not be delivered.
pub fn record_sighting(mut device: Device, scanner: DeviceEventScanner) {
    match db::devices::read(device.mac_address.clone()) {
        Some(recorded) => {
            debug!("Sighting of known device {}; updating", device.mac_address);
            if recorded.name.is_some() {
                device.name = recorded.name.clone();
            }
            if device.ipv4_address.is_empty() {
                device.ipv4_address = recorded.ipv4_address.clone();
            }
            if let Err(err) = db::devices::seen(
                device.mac_address.clone(),
                device.ipv4_address.clone(),
                device.vendor.clone(),
                device.device_type.clone(),
                device.name.clone(),
            ) {
                error!("Failed to update device {}: {err}", device.mac_address);
                return;
            }
            // Ignoring errors: do not stop the loop if notification delivery fails.
            events::trigger_existing_device(recorded, device, scanner).ok();
        }
        None => {
            debug!("New device {} discovered; inserting", device.mac_address);
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert device {}: {err}", device.mac_address);
                return;
            }
            // Ignoring errors: do not stop the loop if notification delivery fails.
            events::trigger_new_device(device, scanner).ok();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;
    use chrono::Utc;

    #[tokio::test]
    async fn inserts_an_unknown_device() {
        tests_common::setup().await;
        let mac = "de:ad:be:ef:00:01".to_string();

        let mut device = Device::new(
            mac.clone(),
            "192.168.9.1".to_string(),
            "Acme".to_string(),
            Utc::now(),
        );
        device.name = Some("printer".to_string());

        record_sighting(device, DeviceEventScanner::Arp);

        let stored = db::devices::read(mac).expect("device should have been inserted");
        assert_eq!(stored.ipv4_address, "192.168.9.1");
        assert_eq!(stored.name, Some("printer".to_string()));
    }

    #[tokio::test]
    async fn known_device_keeps_stored_name_and_ip() {
        tests_common::setup().await;
        let mac = "de:ad:be:ef:00:02".to_string();

        // First sighting records a hostname and an IP.
        let mut first = Device::new(
            mac.clone(),
            "192.168.9.2".to_string(),
            "Acme".to_string(),
            Utc::now(),
        );
        first.name = Some("nas".to_string());
        record_sighting(first, DeviceEventScanner::Mdns);

        // A later sighting with no name and no IP (e.g. a DHCP DISCOVER) must not clobber them.
        let later = Device::new(mac.clone(), String::new(), String::new(), Utc::now());
        record_sighting(later, DeviceEventScanner::Dhcp);

        let stored = db::devices::read(mac).expect("device should exist");
        assert_eq!(stored.name, Some("nas".to_string()));
        assert_eq!(stored.ipv4_address, "192.168.9.2");
    }
}
