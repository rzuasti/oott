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

/// Passively snoop DHCP DISCOVER/REQUEST broadcasts and feed discovered devices into the
/// same pipeline used by the ARP, mDNS and SSDP scanners (devices table + events +
/// notifications). Because a device must request an address before doing almost anything
/// else, this catches new devices very early — often before they have an IP.
pub async fn listen() -> Result<(), Box<dyn std::error::Error>> {
    if !get_settings().dhcp_scanner.enabled {
        info!("DHCP scanner disabled in configuration; not starting");
        return Ok(());
    }

    let socket = finder::open_socket()?;
    status::set_listening();
    info!("DHCP scanner listening for client requests");

    let mut buf = [0u8; 1500];
    loop {
        let len = match socket.recv_from(&mut buf).await {
            Ok((len, _src)) => len,
            Err(err) => {
                warn!("DHCP socket receive error: {err}");
                continue;
            }
        };

        let discovery = match finder::parse_packet(&buf[..len]) {
            Some(d) => d,
            None => continue, // server reply, non-Ethernet, other message type, garbage
        };

        process_discovery(discovery).await;
    }
}

async fn process_discovery(discovery: finder::DhcpDiscovery) {
    let mac = discovery.mac;

    // Unlike mDNS/SSDP, the MAC is carried in the packet (chaddr), so no ARP probe is
    // needed. Privacy/locally-administered MACs have no real OUI, so the lookup returns
    // an empty vendor; there is no DHCP equivalent of a service list to fall back on, so
    // it is left empty (the DB layer preserves any previously known vendor).
    let vendor = mac_vendor_finder::find(mac.get(0..8).unwrap_or("").to_string());

    let ip = discovery.ip_hint.map(|ip| ip.to_string());
    let mut device = Device::new(
        mac.clone(),
        ip.clone().unwrap_or_default(),
        vendor,
        Local::now().to_utc(),
    );
    device.device_type = vendor_device_type_finder::find(&device.vendor);
    device.name = discovery.hostname;

    match db::devices::read(mac.clone()) {
        Some(recorded) => {
            debug!("DHCP sighting of known device {mac}; updating");
            // Keep a previously stored name (likely a richer hostname from mDNS) rather
            // than overwriting it.
            if recorded.name.is_some() {
                device.name = recorded.name.clone();
            }
            // A DISCOVER carries no assigned IP. Don't clobber a known good address with an
            // empty string; reuse the recorded one when this packet has no IP hint.
            if ip.is_none() {
                device.ipv4_address = recorded.ipv4_address.clone();
            }
            if let Err(err) = db::devices::seen(
                device.mac_address.clone(),
                device.ipv4_address.clone(),
                device.vendor.clone(),
                device.device_type.clone(),
                device.name.clone(),
            ) {
                error!("Failed to update DHCP device {mac}: {err}");
                return;
            }
            // Ignoring errors: do not stop the listener if notification delivery fails
            events::trigger_existing_device(recorded, device, DeviceEventScanner::Dhcp).ok();
        }
        None => {
            debug!("New device {mac} discovered via DHCP; inserting");
            if let Err(err) = db::devices::insert(device.clone()) {
                error!("Failed to insert DHCP device {mac}: {err}");
                return;
            }
            events::trigger_new_device(device, DeviceEventScanner::Dhcp).ok();
        }
    }

    status::record_discovery(&mac);
}
