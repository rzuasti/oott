use std::net::{IpAddr, Ipv4Addr};
use std::time::Duration;

use log::{debug, info, warn};
use tokio_util::sync::CancellationToken;

use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::scanners::common::enrichment::build_device;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;

/// Passively listen for mDNS/Bonjour announcements and feed discovered devices into the same
/// pipeline used by the ARP scanner (devices table + events + notifications).
pub async fn listen(shutdown: CancellationToken) -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().mdns_scanner.enabled {
        info!("mDNS scanner disabled in configuration; not starting");
        return Ok(());
    }

    let interface = get_settings().networking.interface.clone();
    let socket = finder::open_socket(interface.clone())?;
    status::STATUS.set_listening();
    info!("mDNS scanner listening for announcements");

    let probe_timeout = Duration::from(get_settings().mdns_scanner.probe_timeout);

    let mut buf = [0u8; 4096];
    loop {
        let (len, src) = tokio::select! {
            _ = shutdown.cancelled() => break,
            result = socket.recv_from(&mut buf) => match result {
                Ok(value) => value,
                Err(err) => {
                    warn!("mDNS socket receive error: {err}");
                    continue;
                }
            },
        };

        let src_ip = match src.ip() {
            IpAddr::V4(ip) => ip,
            IpAddr::V6(_) => continue, // the device model is IPv4-only
        };

        let announcement = finder::parse_announcement(&buf[..len]);
        let hostname = match announcement.hostnames.into_iter().next() {
            Some(host) => host,
            None => continue,
        };

        process_announcement(
            src_ip,
            hostname,
            announcement.service_types,
            interface.clone(),
            probe_timeout,
        )
        .await;
    }

    info!("mDNS scanner shutting down");
    Ok(())
}

async fn process_announcement(
    src_ip: Ipv4Addr,
    hostname: String,
    service_types: Vec<String>,
    interface: Option<String>,
    probe_timeout: Duration,
) {
    let mac =
        match crate::utils::network::resolve_mac_address(src_ip, interface, probe_timeout).await {
            Some(mac) => mac.to_string(),
            None => {
                debug!("Could not resolve MAC for mDNS device {src_ip} ({hostname}); skipping");
                return;
            }
        };

    // The advertised mDNS service types let build_device deduce a vendor for privacy MACs whose
    // OUI lookup fails.
    let device = build_device(
        mac.clone(),
        src_ip.to_string(),
        &service_types,
        Some(hostname),
    );

    pipeline::record_and_notify(device, DeviceEventScanner::Mdns);
    status::STATUS.record_discovery(&mac);
}
