use std::net::Ipv4Addr;
use std::time::{Duration, Instant};

use log::debug;
use pnet::datalink::{self, Channel, Config, NetworkInterface};
use pnet::ipnetwork::IpNetwork;
use pnet::packet::arp::{ArpHardwareTypes, ArpOperations, ArpPacket, MutableArpPacket};
use pnet::packet::ethernet::{EtherTypes, EthernetPacket, MutableEthernetPacket};
use pnet::packet::{MutablePacket, Packet};
use pnet::util::MacAddr;

const PROC_NET_ARP: &str = "/proc/net/arp";

/// Select the network interface to use for scanning.
///
/// If `configured` names an interface, returns that interface as long as it is up.
/// Otherwise, auto-selects the first interface that is up, not loopback, and has an
/// IPv4 address. Returns `None` if no suitable interface is found.
pub fn select_interface<'a>(
    interfaces: &'a [NetworkInterface],
    configured: &Option<String>,
) -> Option<&'a NetworkInterface> {
    match configured {
        Some(name) => interfaces
            .iter()
            .filter(|el| el.is_up())
            .find(|el| &el.name == name),
        None => interfaces
            .iter()
            .find(|el| el.is_up() && !el.is_loopback() && el.ips.iter().any(|ip| ip.is_ipv4())),
    }
}

/// Resolve the MAC address for an IPv4 address.
///
/// Tries the OS neighbor cache (`/proc/net/arp`) first to stay passive; if the IP is not
/// present there, falls back to a single targeted ARP probe on the given interface. Returns
/// `None` if neither method resolves the address.
pub async fn resolve_mac_address(
    ip: Ipv4Addr,
    interface: Option<String>,
    probe_timeout: Duration,
) -> Option<MacAddr> {
    if let Ok(contents) = std::fs::read_to_string(PROC_NET_ARP)
        && let Some(mac) = parse_proc_net_arp(&contents, ip)
    {
        debug!("Resolved {ip} -> {mac} via OS ARP cache");
        return mac.parse::<MacAddr>().ok();
    }

    debug!("{ip} not in ARP cache, sending a targeted ARP probe");
    tokio::task::spawn_blocking(move || probe_mac(ip, interface, probe_timeout))
        .await
        .ok()
        .flatten()
}

/// Parse the contents of `/proc/net/arp` and return the MAC address (as a string) for the
/// given IP, or `None` if it is absent or its entry is incomplete.
fn parse_proc_net_arp(contents: &str, ip: Ipv4Addr) -> Option<String> {
    let ip_str = ip.to_string();
    // First line is a header.
    for line in contents.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() >= 4 && cols[0] == ip_str {
            let flags = cols[2];
            let mac = cols[3];
            // 0x0 flags means an incomplete entry; the all-zero MAC is not usable.
            if flags == "0x0" || mac == "00:00:00:00:00:00" {
                return None;
            }
            return Some(mac.to_string());
        }
    }
    None
}

/// Send a single ARP request for `target_ip` and wait up to `timeout` for the reply.
/// Blocking; intended to run inside `spawn_blocking`.
fn probe_mac(target_ip: Ipv4Addr, interface: Option<String>, timeout: Duration) -> Option<MacAddr> {
    let all_interfaces = datalink::interfaces();
    let iface = select_interface(&all_interfaces, &interface)?;
    let source_mac = iface.mac?;
    let source_ip = iface.ips.iter().find_map(|el| match el {
        IpNetwork::V4(v4) => Some(v4.ip()),
        _ => None,
    })?;

    let config = Config {
        read_timeout: Some(timeout),
        ..Default::default()
    };
    let (mut tx, mut rx) = match datalink::channel(iface, config) {
        Ok(Channel::Ethernet(tx, rx)) => (tx, rx),
        _ => return None,
    };

    let mut arp_buf = [0u8; 28];
    let mut arp_packet = MutableArpPacket::new(&mut arp_buf).unwrap();
    arp_packet.set_hardware_type(ArpHardwareTypes::Ethernet);
    arp_packet.set_protocol_type(EtherTypes::Ipv4);
    arp_packet.set_hw_addr_len(6);
    arp_packet.set_proto_addr_len(4);
    arp_packet.set_operation(ArpOperations::Request);
    arp_packet.set_sender_hw_addr(source_mac);
    arp_packet.set_sender_proto_addr(source_ip);
    arp_packet.set_target_hw_addr(MacAddr::zero());
    arp_packet.set_target_proto_addr(target_ip);

    let mut eth_buf = [0u8; 42];
    let mut eth_packet = MutableEthernetPacket::new(&mut eth_buf).unwrap();
    eth_packet.set_destination(MacAddr::broadcast());
    eth_packet.set_source(source_mac);
    eth_packet.set_ethertype(EtherTypes::Arp);
    eth_packet.set_payload(arp_packet.packet_mut());

    tx.send_to(eth_packet.to_immutable().packet(), Some(iface.clone()));

    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        let buffer = match rx.next() {
            Ok(buffer) => buffer,
            Err(_) => continue, // read timed out; loop re-checks the deadline
        };
        let Some(eth) = EthernetPacket::new(buffer) else {
            continue;
        };
        if eth.get_ethertype() != EtherTypes::Arp {
            continue;
        }
        let Some(arp) = ArpPacket::new(eth.payload()) else {
            continue;
        };
        if arp.get_operation() == ArpOperations::Reply && arp.get_sender_proto_addr() == target_ip {
            return Some(arp.get_sender_hw_addr());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use pnet::ipnetwork::IpNetwork;

    // Raw Linux IFF flag values used by pnet's is_up() / is_loopback()
    const IFF_UP: u32 = 0x1;
    const IFF_LOOPBACK: u32 = 0x8;

    fn make_interface(name: &str, up: bool, loopback: bool, ipv4: bool) -> NetworkInterface {
        let mut flags: u32 = 0;
        if up {
            flags |= IFF_UP;
        }
        if loopback {
            flags |= IFF_LOOPBACK;
        }
        let ips = if ipv4 {
            vec![IpNetwork::V4("192.168.1.1/24".parse().unwrap())]
        } else {
            vec![]
        };
        NetworkInterface {
            name: name.to_string(),
            description: String::new(),
            index: 0,
            mac: None,
            ips,
            flags,
        }
    }

    #[test]
    fn test_select_configured_interface_found() {
        let ifaces = vec![
            make_interface("eth0", true, false, true),
            make_interface("wlan0", true, false, true),
        ];
        let result = select_interface(&ifaces, &Some("wlan0".to_string()));
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "wlan0");
    }

    #[test]
    fn test_select_configured_interface_not_found() {
        let ifaces = vec![make_interface("eth0", true, false, true)];
        let result = select_interface(&ifaces, &Some("missing0".to_string()));
        assert!(result.is_none());
    }

    #[test]
    fn test_select_configured_interface_down_not_found() {
        let ifaces = vec![make_interface("eth0", false, false, true)];
        let result = select_interface(&ifaces, &Some("eth0".to_string()));
        assert!(result.is_none());
    }

    #[test]
    fn test_auto_select_skips_loopback() {
        let ifaces = vec![
            make_interface("lo", true, true, true),
            make_interface("eth0", true, false, true),
        ];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "eth0");
    }

    #[test]
    fn test_auto_select_only_loopback_returns_none() {
        let ifaces = vec![make_interface("lo", true, true, true)];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_none());
    }

    #[test]
    fn test_auto_select_skips_interface_without_ipv4() {
        let ifaces = vec![
            make_interface("eth0", true, false, false),
            make_interface("wlan0", true, false, true),
        ];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "wlan0");
    }

    const SAMPLE: &str = "IP address       HW type     Flags       HW address            Mask     Device\n\
192.168.0.10     0x1         0x2         aa:bb:cc:dd:ee:ff     *        eth0\n\
192.168.0.11     0x1         0x0         00:00:00:00:00:00     *        eth0\n";

    #[test]
    fn test_parse_known_complete_entry() {
        let mac = parse_proc_net_arp(SAMPLE, Ipv4Addr::new(192, 168, 0, 10));
        assert_eq!(mac, Some("aa:bb:cc:dd:ee:ff".to_string()));
    }

    #[test]
    fn test_parse_incomplete_entry_is_none() {
        let mac = parse_proc_net_arp(SAMPLE, Ipv4Addr::new(192, 168, 0, 11));
        assert_eq!(mac, None);
    }

    #[test]
    fn test_parse_absent_ip_is_none() {
        let mac = parse_proc_net_arp(SAMPLE, Ipv4Addr::new(10, 0, 0, 1));
        assert_eq!(mac, None);
    }
}
