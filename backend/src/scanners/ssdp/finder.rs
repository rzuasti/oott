use std::net::{Ipv4Addr, SocketAddrV4};

use log::{debug, info};
use pnet::datalink;
use pnet::ipnetwork::IpNetwork;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::net::UdpSocket;

use crate::utils::network::select_interface;

const SSDP_GROUP: Ipv4Addr = Ipv4Addr::new(239, 255, 255, 250);
const SSDP_PORT: u16 = 1900;

/// Open a UDP socket that passively listens for SSDP/UPnP multicast announcements on the given
/// interface. The socket is bound with address/port reuse so it coexists with other SSDP
/// responders (e.g. minidlna, gssdp-scan) already using port 1900.
pub fn open_socket(interface: Option<String>) -> Result<UdpSocket, Box<dyn std::error::Error>> {
    let all_interfaces = datalink::interfaces();
    let iface = select_interface(&all_interfaces, &interface)
        .ok_or("No suitable interface found for the SSDP listener")?;
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
    socket.bind(&SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, SSDP_PORT).into())?;
    socket.join_multicast_v4(&SSDP_GROUP, &iface_ip)?;
    socket.set_nonblocking(true)?;

    let udp = UdpSocket::from_std(socket.into())?;
    info!(
        "SSDP listener bound to port {SSDP_PORT} on interface {} ({iface_ip})",
        iface.name
    );
    Ok(udp)
}

/// The contents of an SSDP NOTIFY announcement relevant to device discovery.
pub struct Announcement {
    /// SERVER header value (e.g. `Linux/3.14 UPnP/1.1 MiniDLNA/1.3.0`). Used as a name hint.
    pub server: Option<String>,
    /// NT header values describing the device/service type
    /// (e.g. `urn:schemas-upnp-org:device:MediaServer:1`).
    pub device_types: Vec<String>,
}

/// Parse a raw SSDP packet into an `Announcement`. Returns `None` for anything that is not a
/// live device announcement (byebye, M-SEARCH requests, HTTP responses, unparseable garbage).
///
/// SSDP messages are text-based HTTP/1.x style. We accept both `ssdp:alive` and `ssdp:update`
/// (UPnP 1.1 bootID change) as "device is alive" signals.
pub fn parse_announcement(buf: &[u8]) -> Option<Announcement> {
    let text = match std::str::from_utf8(buf) {
        Ok(t) => t,
        Err(err) => {
            debug!("Ignoring non-UTF8 SSDP packet: {err}");
            return None;
        }
    };

    // Tolerate bare-LF line endings (some embedded devices) by splitting on `\n` and stripping
    // any trailing `\r`.
    let mut lines = text.split('\n').map(|l| l.strip_suffix('\r').unwrap_or(l));

    let first_line = lines.next().unwrap_or("");
    if !first_line.to_ascii_uppercase().starts_with("NOTIFY ") {
        return None;
    }

    let mut server: Option<String> = None;
    let mut device_types: Vec<String> = Vec::new();
    let mut nts: Option<String> = None;

    for line in lines {
        if line.is_empty() {
            continue;
        }
        let mut parts = line.splitn(2, ':');
        let key = match parts.next() {
            Some(k) => k.trim().to_ascii_lowercase(),
            None => continue,
        };
        let value = match parts.next() {
            Some(v) => v.trim().to_string(),
            None => continue,
        };
        if value.is_empty() {
            continue;
        }
        match key.as_str() {
            "nts" => nts = Some(value.to_ascii_lowercase()),
            "nt" => device_types.push(value),
            "server" => server = Some(value),
            _ => {}
        }
    }

    match nts.as_deref() {
        Some("ssdp:alive") | Some("ssdp:update") => Some(Announcement {
            server,
            device_types,
        }),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn alive_packet() -> Vec<u8> {
        let body = "NOTIFY * HTTP/1.1\r\n\
                    HOST: 239.255.255.250:1900\r\n\
                    CACHE-CONTROL: max-age=1800\r\n\
                    LOCATION: http://192.168.1.100:49152/rootDesc.xml\r\n\
                    NT: urn:schemas-upnp-org:device:MediaServer:1\r\n\
                    NTS: ssdp:alive\r\n\
                    SERVER: Linux/3.14 UPnP/1.1 MiniDLNA/1.3.0\r\n\
                    USN: uuid:abcd::urn:schemas-upnp-org:device:MediaServer:1\r\n\r\n";
        body.as_bytes().to_vec()
    }

    #[test]
    fn test_parse_alive_extracts_server_and_nt() {
        let announcement = parse_announcement(&alive_packet()).expect("alive packet");
        assert_eq!(
            announcement.server.as_deref(),
            Some("Linux/3.14 UPnP/1.1 MiniDLNA/1.3.0")
        );
        assert_eq!(
            announcement.device_types,
            vec!["urn:schemas-upnp-org:device:MediaServer:1".to_string()]
        );
    }

    #[test]
    fn test_parse_alive_preserves_location_with_embedded_colons() {
        // Just ensure LOCATION with `:` in the value does not corrupt subsequent header parsing.
        let announcement = parse_announcement(&alive_packet()).expect("alive packet");
        assert!(announcement.server.is_some());
        assert!(!announcement.device_types.is_empty());
    }

    #[test]
    fn test_parse_update_accepted() {
        let body = "NOTIFY * HTTP/1.1\r\n\
                    HOST: 239.255.255.250:1900\r\n\
                    NT: upnp:rootdevice\r\n\
                    NTS: ssdp:update\r\n\
                    SERVER: Foo/1.0\r\n\
                    USN: uuid:abcd::upnp:rootdevice\r\n\r\n";
        let announcement = parse_announcement(body.as_bytes()).expect("update packet");
        assert_eq!(announcement.server.as_deref(), Some("Foo/1.0"));
    }

    #[test]
    fn test_parse_byebye_returns_none() {
        let body = "NOTIFY * HTTP/1.1\r\n\
                    HOST: 239.255.255.250:1900\r\n\
                    NT: upnp:rootdevice\r\n\
                    NTS: ssdp:byebye\r\n\
                    USN: uuid:abcd::upnp:rootdevice\r\n\r\n";
        assert!(parse_announcement(body.as_bytes()).is_none());
    }

    #[test]
    fn test_parse_http_response_returns_none() {
        let body = "HTTP/1.1 200 OK\r\n\
                    CACHE-CONTROL: max-age=1800\r\n\
                    SERVER: Foo/1.0\r\n\r\n";
        assert!(parse_announcement(body.as_bytes()).is_none());
    }

    #[test]
    fn test_parse_garbage_returns_none() {
        assert!(parse_announcement(&[0xff, 0x00, 0x13]).is_none());
    }

    #[test]
    fn test_parse_missing_server_header() {
        let body = "NOTIFY * HTTP/1.1\r\n\
                    HOST: 239.255.255.250:1900\r\n\
                    NT: upnp:rootdevice\r\n\
                    NTS: ssdp:alive\r\n\
                    USN: uuid:abcd::upnp:rootdevice\r\n\r\n";
        let announcement = parse_announcement(body.as_bytes()).expect("alive packet");
        assert!(announcement.server.is_none());
        assert_eq!(announcement.device_types, vec!["upnp:rootdevice".to_string()]);
    }

    #[test]
    fn test_parse_bare_lf_line_endings() {
        let body = "NOTIFY * HTTP/1.1\n\
                    HOST: 239.255.255.250:1900\n\
                    NT: upnp:rootdevice\n\
                    NTS: ssdp:alive\n\
                    SERVER: Bar/2.0\n\n";
        let announcement = parse_announcement(body.as_bytes()).expect("alive packet");
        assert_eq!(announcement.server.as_deref(), Some("Bar/2.0"));
    }
}
