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

/// Passively listen for mDNS/Bonjour announcements and feed discovered devices into the same
/// pipeline used by the ARP scanner (devices table + events + notifications).
pub async fn listen() -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().mdns_scanner.enabled {
        info!("mDNS scanner disabled in configuration; not starting");
        return Ok(());
    }

    let interface = get_settings().networking.interface.clone();
    let socket = finder::open_socket(interface.clone())?;
    status::set_listening();
    info!("mDNS scanner listening for announcements");

    let probe_timeout = Duration::from(get_settings().mdns_scanner.probe_timeout);

    let mut buf = [0u8; 4096];
    loop {
        let (len, src) = match socket.recv_from(&mut buf).await {
            Ok(value) => value,
            Err(err) => {
                warn!("mDNS socket receive error: {err}");
                continue;
            }
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

    let mut vendor = mac_vendor_finder::find(mac.get(0..8).unwrap_or("").to_string());
    // Privacy MACs are locally administered and have no real OUI, so the lookup above fails.
    // Fall back to the vendor-specific mDNS services the device advertises.
    if vendor.is_empty() && crate::utils::network::is_locally_administered(&mac) {
        vendor = crate::data::service_vendor_finder::find(&service_types);
    }
    let mut device = Device::new(
        mac.clone(),
        src_ip.to_string(),
        vendor,
        Local::now().to_utc(),
    );
    device.device_type = vendor_device_type_finder::find(&device.vendor);
    device.name = Some(hostname);

    match db::devices::read(mac.clone()) {
        Some(recorded) => {
            debug!("mDNS sighting of known device {mac}; updating");
            // Keep the previously stored hostname rather than overwriting it with this
            // announcement's hostname.
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
                error!("Failed to update mDNS device {mac}: {err}");
                return;
            }
            // Ignoring errors: do not stop the listener if notification delivery fails
            events::trigger_existing_device(recorded, device, DeviceEventScanner::Mdns).ok();
        }
        None => {
            debug!("New device {mac} discovered via mDNS; inserting");
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert mDNS device {mac}: {err}");
                return;
            }
            events::trigger_new_device(device, DeviceEventScanner::Mdns).ok();
        }
    }

    status::record_discovery();
}
