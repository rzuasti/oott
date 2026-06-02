use super::finder;
use super::status;
use crate::db;
use crate::events;
use crate::model::device_events::DeviceEventScanner;
use crate::settings::get_settings;
use chrono::Utc;
use log::{debug, error, info};
use tokio::time::{Duration, sleep};

/// Periodically poll an SNMP agent (typically the gateway) for its ARP/neighbour cache and feed
/// the discovered devices into the same pipeline used by the other scanners (devices table +
/// events + notifications). Unlike the ARP scanner this generates no traffic on the local
/// segment and can surface devices on subnets the host cannot reach directly.
pub async fn scan() -> Result<(), Box<dyn std::error::Error>> {
    let config = &get_settings().snmp_scanner;
    if !config.enabled {
        info!("SNMP scanner disabled in configuration; not starting");
        return Ok(());
    }
    if config.target.is_empty() {
        info!("SNMP scanner has no target configured; not starting");
        return Ok(());
    }

    info!("SNMP scanner polling agent at {}", config.target);

    loop {
        status::set_running();

        // A failed poll (unreachable agent, timeout, bad community) must not stop the loop;
        // log it and try again next cycle.
        match finder::find(config).await {
            Ok(devices) => {
                info!("SNMP poll found {} devices in the ARP cache", devices.len());
                for device in devices.iter() {
                    process_device(device);
                }
            }
            Err(err) => error!("SNMP poll of {} failed: {err}", config.target),
        }

        let wait = Duration::from(config.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "SNMP scan finished. Sleeping for {}",
            config.wait_between_scans
        );
        status::set_waiting(next_scan_at);
        sleep(wait).await;
    }
}

fn process_device(device: &crate::model::devices::Device) {
    match db::devices::read(device.mac_address.clone()) {
        Some(recorded_device) => {
            debug!("SNMP sighting of known device {}; updating", device.mac_address);
            if let Err(err) = db::devices::seen(
                device.mac_address.clone(),
                device.ipv4_address.clone(),
                device.vendor.clone(),
                device.device_type.clone(),
                device.name.clone(),
            ) {
                error!("Failed to update SNMP device {}: {err}", device.mac_address);
                return;
            }
            // Ignoring errors: do not stop the loop if notification delivery fails.
            events::trigger_existing_device(recorded_device, device.clone(), DeviceEventScanner::Snmp)
                .ok();
        }
        None => {
            debug!(
                "New device {} discovered via SNMP; inserting",
                device.mac_address
            );
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert SNMP device {}: {err}", device.mac_address);
                return;
            }
            events::trigger_new_device(device.clone(), DeviceEventScanner::Snmp).ok();
        }
    }
}
