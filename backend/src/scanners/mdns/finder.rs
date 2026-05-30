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

/// The contents of an mDNS/DNS announcement relevant to device discovery.
pub struct Announcement {
    /// Hostnames advertised by A records (e.g. `Test-Device.local`).
    pub hostnames: Vec<String>,
    /// Service types advertised by PTR records (e.g. `_airplay._tcp.local`).
    pub service_types: Vec<String>,
}

/// Parse a raw mDNS/DNS message into the hostnames (A records) and service types (PTR records)
/// it advertises. Returns an empty `Announcement` if the packet cannot be parsed.
pub fn parse_announcement(buf: &[u8]) -> Announcement {
    let packet = match Packet::parse(buf) {
        Ok(p) => p,
        Err(err) => {
            debug!("Ignoring unparseable mDNS packet: {err}");
            return Announcement {
                hostnames: Vec::new(),
                service_types: Vec::new(),
            };
        }
    };

    let records = || {
        packet
            .answers
            .iter()
            .chain(packet.additional_records.iter())
    };

    let hostnames = records()
        .filter(|record| matches!(record.rdata, RData::A(_)))
        .map(|record| record.name.to_string())
        .filter(|host| !host.is_empty())
        .collect();

    let service_types = records()
        .filter(|record| matches!(record.rdata, RData::PTR(_)))
        .map(|record| record.name.to_string())
        .filter(|service| !service.is_empty())
        .collect();

    Announcement {
        hostnames,
        service_types,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use simple_dns::rdata::{A, PTR};
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

        let announcement = parse_announcement(&bytes);
        assert!(
            announcement
                .hostnames
                .iter()
                .any(|h| h.contains("Test-Device.local")),
            "expected to extract Test-Device.local, got {:?}",
            announcement.hostnames
        );
    }

    #[test]
    fn test_parse_announcement_extracts_service_type() {
        let mut packet = Packet::new_reply(1);
        let service = Name::new("_airplay._tcp.local").unwrap();
        let target = Name::new("Apple-TV._airplay._tcp.local").unwrap();
        packet.answers.push(ResourceRecord::new(
            service,
            CLASS::IN,
            120,
            RData::PTR(PTR(target)),
        ));
        let bytes = packet.build_bytes_vec().unwrap();

        let announcement = parse_announcement(&bytes);
        assert!(
            announcement
                .service_types
                .iter()
                .any(|s| s.contains("_airplay._tcp.local")),
            "expected to extract _airplay._tcp.local, got {:?}",
            announcement.service_types
        );
    }

    #[test]
    fn test_parse_announcement_ignores_garbage() {
        let announcement = parse_announcement(&[0xff, 0x00, 0x13]);
        assert!(announcement.hostnames.is_empty());
        assert!(announcement.service_types.is_empty());
    }
}
