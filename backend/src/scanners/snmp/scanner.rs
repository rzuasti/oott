use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::notifications;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;
use chrono::Utc;
use log::{error, info};
use tokio::time::{Duration, sleep};
use tokio_util::sync::CancellationToken;

/// Periodically poll an SNMP agent (typically the gateway) for its ARP/neighbour cache and feed
/// the discovered devices into the same pipeline used by the other scanners (devices table +
/// events + notifications). Unlike the ARP scanner this generates no traffic on the local
/// segment and can surface devices on subnets the host cannot reach directly.
pub async fn scan(shutdown: CancellationToken) -> Result<(), Box<dyn std::error::Error>> {
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
        status::STATUS.set_running();

        // A failed poll (unreachable agent, timeout, bad community) must not stop the loop;
        // log it and try again next cycle. Abandon an in-flight poll immediately on shutdown.
        let poll = tokio::select! {
            _ = shutdown.cancelled() => break,
            result = finder::find(config) => result,
        };
        match poll {
            Ok(devices) => {
                info!("SNMP poll found {} devices in the ARP cache", devices.len());
                status::STATUS.record_scan(&devices);
                // Accumulate every change so the whole poll emits one consolidated notification
                // per type (see notifications::notify) rather than one per device.
                let mut changes = Vec::new();
                for device in devices.iter() {
                    changes.extend(pipeline::record_sighting(
                        device.clone(),
                        DeviceEventScanner::Snmp,
                    ));
                }
                notifications::notify(changes);
            }
            Err(err) => error!("SNMP poll of {} failed: {err}", config.target),
        }

        let wait = Duration::from(config.wait_between_scans);
        let next_scan_at = Utc::now() + chrono::Duration::from_std(wait).unwrap();
        info!(
            "SNMP scan finished. Sleeping for {}",
            config.wait_between_scans
        );
        status::STATUS.set_waiting(next_scan_at);
        // Wake early if shutdown is requested instead of sleeping out the whole interval.
        tokio::select! {
            _ = shutdown.cancelled() => break,
            _ = sleep(wait) => {}
        }
    }

    info!("SNMP scanner shutting down");
    Ok(())
}
