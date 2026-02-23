mod error;
mod pushover;

use std::time::Duration;

use crate::settings::get_settings;
use crate::{events::error::DeliveryError, model::devices::Device};
use chrono::Local;
use duration_string::DurationString;
use log::{debug, info, warn};

// Private helper function to deliver messages
fn send_message(body: String) -> Result<(), DeliveryError> {
    debug!("About to send notification ({body}).");

    match get_settings().notifications.method.as_str() {
        "pushover" => {
            pushover::send_message(body)?;
        }
        other => {
            warn!("Notification method set to '{other}'. Set logs to 'info' to see notifications.");
            info!("Notification: {body}");
        }
    };

    Ok(())
}

pub fn trigger_new_device(device: Device) -> Result<(), DeliveryError> {
    send_message(format!("New device found in your network: {device}"))?;
    Ok(())
}

pub fn trigger_existing_device(
    existing_device: Device,
    new_device: Device,
) -> Result<(), DeliveryError> {
    // Notify if the device comes back online after not being seen for the configured period
    let elapsed_since_last_seen: Duration = (Local::now().to_utc() - existing_device.last_seen)
        .to_std()
        .unwrap_or(Duration::from_secs(0));

    if elapsed_since_last_seen
        >= Duration::from(get_settings().notifications.notify_when_not_seen_for)
    {
        send_message(format!(
            "Device MAC {} - IP {} - Vendor {} came back online after {}.",
            new_device.mac_address,
            new_device.ipv4_address,
            new_device.vendor,
            String::from(DurationString::from(Duration::from_secs(
                elapsed_since_last_seen.as_secs()
            )))
        ))?;
    }

    // Notify if the devices vendor and/or IP changed
    if (existing_device.ipv4_address != new_device.ipv4_address)
        && (existing_device.vendor != new_device.vendor)
    {
        send_message(format!(
            "Device with MAC {} changed IP address from {} to {} and vendor from {} to {}.",
            existing_device.mac_address,
            existing_device.ipv4_address,
            new_device.ipv4_address,
            existing_device.vendor,
            new_device.vendor
        ))?;
    } else if existing_device.ipv4_address != new_device.ipv4_address {
        send_message(format!(
            "Device with MAC {} ({}) changed IP address from {} to {}.",
            existing_device.mac_address,
            new_device.vendor,
            existing_device.ipv4_address,
            new_device.ipv4_address
        ))?;
    } else if existing_device.vendor != new_device.vendor {
        send_message(format!(
            "Device with MAC {} ({}) changed vendor from {} to {}.",
            existing_device.mac_address,
            existing_device.ipv4_address,
            existing_device.vendor,
            new_device.vendor
        ))?;
    };

    Ok(())
}
