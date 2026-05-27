mod error;
mod pushover;

use std::error::Error;
use std::time::Duration;

use crate::db;
use crate::model::devices::Device;
use crate::model::notifications::Notification;
use crate::model::notifications::NotificationType;
use crate::settings::get_settings;
use chrono::{Local, Utc};
use duration_string::DurationString;
use log::{debug, info, warn};

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
    let notification = Notification::new(
        Utc::now(),
        NotificationType::NewDeviceFound,
        "New device found in your network".to_string(),
        format!(
            "A new device was found in your network:\n\nMAC address: {}\nIP address: {}\nVendor: {}",
            device.mac_address, device.ipv4_address, device.vendor
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
                "Device:\n\nMAC address: {}\nIP address: {}\nVendor: {}\n\ncame back online after {}.",
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
    if (existing_device.ipv4_address != new_device.ipv4_address)
        && (existing_device.vendor != new_device.vendor)
    {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed vendor and IP address".to_string(),
            format!(
                "Device with MAC address {} has changed:\nIP address from {} to {}\nVendor from {} to {}.",
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
    } else if existing_device.ipv4_address != new_device.ipv4_address {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed IP address".to_string(),
            format!(
                "Device with MAC address {} ({}) has changed:\nIP address from {} to {}.",
                existing_device.mac_address,
                existing_device.vendor,
                existing_device.ipv4_address,
                new_device.ipv4_address,
            ),
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    } else if existing_device.vendor != new_device.vendor {
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            "Device changed vendor".to_string(),
            format!(
                "Device with MAC address {} ({}) has changed:\nVendor from {} to {}.",
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
