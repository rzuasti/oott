mod pushover;

use crate::{device_finders::Device, settings::CONFIG};
use log::{debug, info, warn};

// Private helper function to deliver messages
fn send_message(body: String) -> Result<(), String> {
    debug!("About to send notification ({body}).");

    match CONFIG.notifications.method.as_str() {
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

pub fn trigger_new_device(device: Device) -> Result<(), String> {
    send_message(format!("New device found in your network: {device}"))?;
    Ok(())
}

pub fn trigger_existing_device(existing_device: Device, new_device: Device) -> Result<(), String> {
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
