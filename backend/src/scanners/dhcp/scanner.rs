use log::{info, warn};

use super::finder;
use super::status;
use crate::model::device_events::DeviceEventScanner;
use crate::scanners::common::enrichment::build_device;
use crate::scanners::common::pipeline;
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

        process_discovery(discovery);
    }
}

fn process_discovery(discovery: finder::DhcpDiscovery) {
    let mac = discovery.mac;

    // Unlike mDNS/SSDP, the MAC is carried in the packet (chaddr), so no ARP probe is needed.
    // DHCP advertises no service list, so there is no vendor fallback (pass no service hints); a
    // privacy MAC therefore yields an empty vendor, which the DB layer preserves. A DISCOVER
    // carries no assigned IP, so the address may be empty here — the pipeline keeps any known IP.
    let ipv4 = discovery
        .ip_hint
        .map(|ip| ip.to_string())
        .unwrap_or_default();
    let device = build_device(mac.clone(), ipv4, &[], discovery.hostname);

    pipeline::record_sighting(device, DeviceEventScanner::Dhcp);
    status::record_discovery(&mac);
}
