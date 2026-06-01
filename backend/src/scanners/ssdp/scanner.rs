use std::net::{IpAddr, Ipv4Addr};
use std::time::Duration;

use chrono::Local;
use log::{debug, error, info, warn};

use super::finder;
use super::status;
use crate::data::mac_vendor_finder;
use crate::data::vendor_device_type_finder;
use crate::db;
use crate::events;
use crate::model::device_events::DeviceEventScanner;
use crate::model::devices::Device;
use crate::settings::get_settings;

/// Passively listen for SSDP/UPnP NOTIFY announcements and feed discovered devices into the same
/// pipeline used by the ARP and mDNS scanners (devices table + events + notifications).
pub async fn listen() -> Result<(), Box<dyn std::error::Error>> {
    let interface = get_settings().networking.interface.clone();
    let socket = finder::open_socket(interface.clone())?;
    status::set_listening();
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

    let mut vendor = mac_vendor_finder::find(mac.get(0..8).unwrap_or("").to_string());
    // Privacy MACs are locally administered and have no real OUI, so the lookup above fails.
    // Fall back to the vendor-specific service strings the device advertises (SSDP NT URNs
    // typically won't match this lookup, but the call shape mirrors the mDNS scanner).
    if vendor.is_empty() && crate::utils::network::is_locally_administered(&mac) {
        vendor = crate::data::service_vendor_finder::find(&device_types);
    }
    let mut device = Device::new(
        mac.clone(),
        src_ip.to_string(),
        vendor,
        Local::now().to_utc(),
    );
    device.device_type = vendor_device_type_finder::find(&device.vendor);
    device.name = server_hint;

    match db::devices::read(mac.clone()) {
        Some(recorded) => {
            debug!("SSDP sighting of known device {mac}; updating");
            // Keep the previously stored name (likely a proper hostname from mDNS) rather than
            // overwriting it with the SERVER header string.
            if recorded.name.is_some() {
                device.name = recorded.name.clone();
            }
            if let Err(err) = db::devices::seen(
                device.mac_address.clone(),
                device.ipv4_address.clone(),
                device.vendor.clone(),
                device.device_type.clone(),
                device.name.clone(),
            ) {
                error!("Failed to update SSDP device {mac}: {err}");
                return;
            }
            // Ignoring errors: do not stop the listener if notification delivery fails
            events::trigger_existing_device(recorded, device, DeviceEventScanner::Ssdp).ok();
        }
        None => {
            debug!("New device {mac} discovered via SSDP; inserting");
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert SSDP device {mac}: {err}");
                return;
            }
            events::trigger_new_device(device, DeviceEventScanner::Ssdp).ok();
        }
    }

    status::record_discovery();
}
