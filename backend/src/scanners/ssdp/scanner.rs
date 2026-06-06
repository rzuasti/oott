use std::net::{IpAddr, Ipv4Addr};
use std::time::Duration;

use log::{debug, info, warn};

use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::scanners::common::enrichment::build_device;
use crate::scanners::common::pipeline;
use crate::settings::get_settings;

/// Passively listen for SSDP/UPnP NOTIFY announcements and feed discovered devices into the same
/// pipeline used by the ARP and mDNS scanners (devices table + events + notifications).
pub async fn listen() -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().ssdp_scanner.enabled {
        info!("SSDP scanner disabled in configuration; not starting");
        return Ok(());
    }

    let interface = get_settings().networking.interface.clone();
    let socket = finder::open_socket(interface.clone())?;
    status::STATUS.set_listening();
    info!("SSDP scanner listening for announcements");

    let probe_timeout = Duration::from(get_settings().ssdp_scanner.probe_timeout);

    let mut buf = [0u8; 4096];
    loop {
        let (len, src) = match socket.recv_from(&mut buf).await {
            Ok(value) => value,
            Err(err) => {
                warn!("SSDP socket receive error: {err}");
                continue;
            }
        };

        let src_ip = match src.ip() {
            IpAddr::V4(ip) => ip,
            IpAddr::V6(_) => continue, // the device model is IPv4-only
        };

        let announcement = match finder::parse_announcement(&buf[..len]) {
            Some(a) => a,
            None => continue, // byebye, M-SEARCH, HTTP response, garbage
        };

        process_announcement(
            src_ip,
            announcement.server,
            announcement.device_types,
            interface.clone(),
            probe_timeout,
        )
        .await;
    }
}

async fn process_announcement(
    src_ip: Ipv4Addr,
    server_hint: Option<String>,
    device_types: Vec<String>,
    interface: Option<String>,
    probe_timeout: Duration,
) {
    let mac =
        match crate::utils::network::resolve_mac_address(src_ip, interface, probe_timeout).await {
            Some(mac) => mac.to_string(),
            None => {
                debug!("Could not resolve MAC for SSDP device {src_ip}; skipping");
                return;
            }
        };

    // The advertised SSDP NT device-type URNs rarely match the vendor lookup, but the call shape
    // mirrors the mDNS scanner so build_device can still deduce a vendor for privacy MACs.
    let device = build_device(mac.clone(), src_ip.to_string(), &device_types, server_hint);

    pipeline::record_and_notify(device, DeviceEventScanner::Ssdp);
    status::STATUS.record_discovery(&mac);
}
