use std::net::{Ipv4Addr, SocketAddrV4};

use log::{debug, info};
use pnet::datalink;
use pnet::ipnetwork::IpNetwork;
use simple_dns::Packet;
use simple_dns::rdata::RData;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::net::UdpSocket;

use crate::utils::network::select_interface;

const MDNS_GROUP: Ipv4Addr = Ipv4Addr::new(224, 0, 0, 251);
const MDNS_PORT: u16 = 5353;

/// Open a UDP socket that passively listens for mDNS multicast announcements on the given
/// interface. The socket is bound with address/port reuse so it coexists with other mDNS
/// responders (e.g. avahi) already using port 5353.
pub fn open_socket(interface: Option<String>) -> Result<UdpSocket, Box<dyn std::error::Error>> {
    let all_interfaces = datalink::interfaces();
    let iface = select_interface(&all_interfaces, &interface)
        .ok_or("No suitable interface found for the mDNS listener")?;
    let iface_ip = iface
        .ips
        .iter()
        .find_map(|el| match el {
            IpNetwork::V4(v4) => Some(v4.ip()),
            _ => None,
        })
        .ok_or("Selected interface has no IPv4 address")?;

    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;
    socket.set_reuse_address(true)?;
    #[cfg(unix)]
    socket.set_reuse_port(true)?;
    socket.bind(&SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, MDNS_PORT).into())?;
    socket.join_multicast_v4(&MDNS_GROUP, &iface_ip)?;
    socket.set_nonblocking(true)?;

    let udp = UdpSocket::from_std(socket.into())?;
    info!(
        "mDNS listener bound to port {MDNS_PORT} on interface {} ({iface_ip})",
        iface.name
    );
    Ok(udp)
}

/// Parse a raw mDNS/DNS message and return the hostnames advertised by its A records.
pub fn parse_announcement(buf: &[u8]) -> Vec<String> {
    let packet = match Packet::parse(buf) {
        Ok(p) => p,
        Err(err) => {
            debug!("Ignoring unparseable mDNS packet: {err}");
            return Vec::new();
        }
    };

    packet
        .answers
        .iter()
        .chain(packet.additional_records.iter())
        .filter(|record| matches!(record.rdata, RData::A(_)))
        .map(|record| record.name.to_string())
        .filter(|host| !host.is_empty())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use simple_dns::rdata::A;
    use simple_dns::{CLASS, Name, Packet, ResourceRecord};

    #[test]
    fn test_parse_announcement_extracts_hostname() {
        let mut packet = Packet::new_reply(1);
        let name = Name::new("Test-Device.local").unwrap();
        packet.answers.push(ResourceRecord::new(
            name,
            CLASS::IN,
            120,
            RData::A(A {
                address: u32::from(Ipv4Addr::new(192, 168, 1, 5)),
            }),
        ));
        let bytes = packet.build_bytes_vec().unwrap();

        let hosts = parse_announcement(&bytes);
        assert!(
            hosts.iter().any(|h| h.contains("Test-Device.local")),
            "expected to extract Test-Device.local, got {hosts:?}"
        );
    }

    #[test]
    fn test_parse_announcement_ignores_garbage() {
        assert!(parse_announcement(&[0xff, 0x00, 0x13]).is_empty());
    }
}
