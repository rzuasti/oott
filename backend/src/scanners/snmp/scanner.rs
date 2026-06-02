use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;
use chrono::Utc;
use log::{error, info};
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
                status::record_scan(devices.len() as u64);
                for device in devices.iter() {
                    pipeline::record_sighting(device.clone(), DeviceEventScanner::Snmp);
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
