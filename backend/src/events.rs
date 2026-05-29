mod error;
mod pushover;

use std::error::Error;
use std::time::Duration;

use crate::db;
use crate::model::device_events::{DeviceEvent, DeviceEventType};
use crate::model::devices::Device;
use crate::model::notifications::Notification;
use crate::model::notifications::NotificationType;
use crate::settings::get_settings;
use chrono::{Local, Utc};
use duration_string::DurationString;
use log::{debug, error, info, warn};

// Device name for display in messages; falls back to "(unknown)" for devices with no
// mDNS-discovered hostname (e.g. those found only via ARP).
fn display_name(device: &Device) -> &str {
    device
        .name
        .as_deref()
        .filter(|name| !name.is_empty())
        .unwrap_or("(unknown)")
}

// Whether a re-sighting represents a real vendor change. A scanner that cannot deduce a vendor
// reports an empty string; that is not a change (db::devices::update keeps the known vendor), so
// it must not raise a "vendor changed" notification either. Likewise, first deducing a vendor for a
// device that previously had none is not a change worth notifying about.
fn vendor_changed(existing: &str, new: &str) -> bool {
    !existing.is_empty() && !new.is_empty() && existing != new
}

// Private helper function to deliver messages
fn send_notification(notification: Notification) -> Result<(), Box<dyn Error>> {
    debug!("About to record notification in database");
    db::notifications::insert(notification.clone())?;

    debug!("About to send notification ({notification}).");

    match get_settings().notifications.method.as_str() {
        "pushover" => {
            pushover::send_message(notification.title, notification.body)?;
        }
        other => {
            warn!("Notification method set to '{other}'. Set logs to 'info' to see notifications.");
            info!("Notification: {}", notification.body);
        }
    };

    Ok(())
}

pub fn trigger_new_device(device: Device) -> Result<(), Box<dyn Error>> {
    let event = DeviceEvent::new(
        device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::NewDevice,
        device.ipv4_address.clone(),
        device.vendor.clone(),
    );
    if let Err(err) = db::device_events::insert(event) {
        error!(
            "Failed to record device event for {}: {}",
            device.mac_address, err
        );
    }

    let notification = Notification::new(
        Utc::now(),
        NotificationType::NewDeviceFound,
        "New device found in your network".to_string(),
        format!(
            "A new device was found in your network:\n\nName: {}\nMAC address: {}\nIP address: {}\nVendor: {}",
            display_name(&device),
            device.mac_address,
            device.ipv4_address,
            device.vendor
        ),
        true,
        Some(device.mac_address.clone()),
    );

    send_notification(notification)?;
    Ok(())
}

pub fn trigger_existing_device(
    existing_device: Device,
    new_device: Device,
) -> Result<(), Box<dyn Error>> {
    let event = DeviceEvent::new(
        new_device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::DeviceSeen,
        new_device.ipv4_address.clone(),
        new_device.vendor.clone(),
    );
    if let Err(err) = db::device_events::insert(event) {
        error!(
            "Failed to record device event for {}: {}",
            new_device.mac_address, err
        );
    }

    // Notify if the device comes back online after not being seen for the configured period
    let elapsed_since_last_seen: Duration = (Local::now().to_utc() - existing_device.last_seen)
        .to_std()
        .unwrap_or(Duration::from_secs(0));

    if elapsed_since_last_seen
        >= Duration::from(get_settings().notifications.notify_when_not_seen_for)
    {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceOnlineAfterTime,
            "A device came back online after a while".to_string(),
            format!(
                "Device:\n\nName: {}\nMAC address: {}\nIP address: {}\nVendor: {}\n\ncame back online after {}.",
                display_name(&new_device),
                new_device.mac_address,
                new_device.ipv4_address,
                new_device.vendor,
                String::from(DurationString::from(Duration::from_secs(
                    elapsed_since_last_seen.as_secs()
                )))
            ),
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    }

    // Notify if the devices vendor and/or IP changed
    let ip_changed = existing_device.ipv4_address != new_device.ipv4_address;
    let vendor_changed = vendor_changed(&existing_device.vendor, &new_device.vendor);

    if ip_changed && vendor_changed {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed vendor and IP address".to_string(),
            format!(
                "Device {} (MAC address {}) has changed:\nIP address from {} to {}\nVendor from {} to {}.",
                display_name(&new_device),
                existing_device.mac_address,
                existing_device.ipv4_address,
                new_device.ipv4_address,
                existing_device.vendor,
                new_device.vendor,
            ),
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    } else if ip_changed {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed IP address".to_string(),
            format!(
                "Device {} (MAC address {}, {}) has changed:\nIP address from {} to {}.",
                display_name(&new_device),
                existing_device.mac_address,
                existing_device.vendor,
                existing_device.ipv4_address,
                new_device.ipv4_address,
            ),
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    } else if vendor_changed {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed vendor".to_string(),
            format!(
                "Device {} (MAC address {}, {}) has changed:\nVendor from {} to {}.",
                display_name(&new_device),
                existing_device.mac_address,
                existing_device.ipv4_address,
                existing_device.vendor,
                new_device.vendor,
            ),
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    };

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_new_vendor_is_not_a_change() {
        assert!(!vendor_changed("Apple, Inc.", ""));
    }

    #[test]
    fn different_non_empty_vendor_is_a_change() {
        assert!(vendor_changed("Apple, Inc.", "Google, Inc."));
    }

    #[test]
    fn same_vendor_is_not_a_change() {
        assert!(!vendor_changed("Apple, Inc.", "Apple, Inc."));
    }

    #[test]
    fn newly_deduced_vendor_from_empty_is_not_a_change() {
        assert!(!vendor_changed("", "Apple, Inc."));
    }
}
