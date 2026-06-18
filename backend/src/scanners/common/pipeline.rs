use log::{debug, error};

use crate::db;
use crate::events;
use crate::model::device_events::{DeviceChange, DeviceEventScanner};
use crate::model::devices::Device;
use crate::notifications;

/// Persist a device sighting and record its device event, then return any notification-worthy
/// changes it produced (without sending). This feeds every scanner (ARP, mDNS, SSDP, DHCP, SNMP)
/// through one code path. Active scanners accumulate the changes across a whole scan and pass them
/// to `notifications::notify` once, consolidating per type; passive listeners use
/// `record_and_notify`.
///
/// When the device is already known, the sighting is reconciled with the stored record:
/// - a previously stored hostname is kept rather than overwritten by this sighting's name;
/// - a known IP address is kept when this sighting carries none (an empty string), so a DHCP
///   DISCOVER (which has no assigned IP) never clobbers a good address;
/// - registration, owner, and a non-empty stored vendor/device_type are carried over, so the
///   change passed to the notification layer describes the device as it is stored rather than as
///   this bare sighting saw it.
///
/// Errors are logged and swallowed (an empty list is returned): a scan/listen loop must never stop
/// because a single sighting failed to persist.
pub fn record_sighting(mut device: Device, scanner: DeviceEventScanner) -> Vec<DeviceChange> {
    match db::devices::read(device.mac_address.clone()) {
        Some(recorded) => {
            debug!("Sighting of known device {}; updating", device.mac_address);
            if recorded.name.is_some() {
                device.name = recorded.name.clone();
            }
            if device.ipv4_address.is_empty() {
                device.ipv4_address = recorded.ipv4_address.clone();
            }
            // Carry forward the fields a sighting can never establish or improve, mirroring how
            // db::devices::seen() preserves them: registration and owner are only ever set via the
            // UI, and a non-empty stored vendor/device_type wins over what this sighting deduced.
            // Without this, the reconciled device (used for notifications) would report a
            // registered, typed device as "Not registered" with type "-".
            device.is_registered = recorded.is_registered;
            device.owner = recorded.owner.clone();
            if device.vendor.is_empty() {
                device.vendor = recorded.vendor.clone();
            }
            if !recorded.device_type.is_empty() {
                device.device_type = recorded.device_type.clone();
            }
            if let Err(err) = db::devices::seen(
                device.mac_address.clone(),
                device.ipv4_address.clone(),
                device.vendor.clone(),
                device.device_type.clone(),
                device.name.clone(),
            ) {
                error!("Failed to update device {}: {err}", device.mac_address);
                return Vec::new();
            }
            events::record_known_device(recorded, device, scanner)
        }
        None => {
            debug!("New device {} discovered; inserting", device.mac_address);
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert device {}: {err}", device.mac_address);
                return Vec::new();
            }
            events::record_new_device(device, scanner)
                .into_iter()
                .collect()
        }
    }
}

/// Record a single sighting and immediately send any resulting notification. Used by the passive
/// listeners (mDNS, SSDP, DHCP), which process one device per event and so have nothing to
/// consolidate across a scan.
pub fn record_and_notify(device: Device, scanner: DeviceEventScanner) {
    notifications::notify(record_sighting(device, scanner));
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
    async fn changed_notification_reflects_stored_registration_and_type() {
        tests_common::setup().await;
        let mac = "de:ad:be:ef:00:03".to_string();

        // A device is discovered, then registered with an owner and a device type.
        let first = Device::new(
            mac.clone(),
            "192.168.9.3".to_string(),
            "Acme".to_string(),
            Utc::now(),
        );
        record_sighting(first, DeviceEventScanner::Arp);
        db::devices::register(
            mac.clone(),
            "Alice".to_string(),
            "Smartphone".to_string(),
            None,
        )
        .expect("register should succeed");

        // It is later seen at a different IP by a scanner that carries no vendor or type.
        let moved = Device::new(
            mac.clone(),
            "192.168.9.99".to_string(),
            String::new(),
            Utc::now(),
        );
        let changes = record_sighting(moved, DeviceEventScanner::Arp);

        let new = changes
            .iter()
            .find_map(|change| match change {
                DeviceChange::Changed { new, .. } => Some(new),
                _ => None,
            })
            .expect("an IP change should be reported");

        // The change must describe the device as it is stored, not as the bare sighting saw it.
        assert!(new.is_registered);
        assert_eq!(new.owner, "Alice");
        assert_eq!(new.device_type, "Smartphone");
        assert_eq!(new.vendor, "Acme");
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
