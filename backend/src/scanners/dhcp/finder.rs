use std::net::{Ipv4Addr, SocketAddrV4};

use log::{debug, info};
use socket2::{Domain, Protocol, Socket, Type};
use tokio::net::UdpSocket;

use crate::utils::network::format_mac;

const DHCP_SERVER_PORT: u16 = 67;

// DHCP/BOOTP fixed-header field offsets (RFC 2131).
const OP_OFFSET: usize = 0;
const HTYPE_OFFSET: usize = 1;
const HLEN_OFFSET: usize = 2;
const CIADDR_OFFSET: usize = 4 + 4 + 2 + 2; // hops, xid, secs, flags precede ciaddr
const CHADDR_OFFSET: usize = 28;
const MAGIC_COOKIE_OFFSET: usize = 236;
const OPTIONS_OFFSET: usize = 240;

// The DHCP magic cookie that precedes the options section.
const MAGIC_COOKIE: [u8; 4] = [99, 130, 83, 99];

// Values we care about.
const OP_BOOTREQUEST: u8 = 1;
const HTYPE_ETHERNET: u8 = 1;
const HLEN_ETHERNET: u8 = 6;

const OPTION_PAD: u8 = 0;
const OPTION_END: u8 = 255;
const OPTION_HOSTNAME: u8 = 12;
const OPTION_REQUESTED_IP: u8 = 50;
const OPTION_MESSAGE_TYPE: u8 = 53;

const DHCP_DISCOVER: u8 = 1;
const DHCP_REQUEST: u8 = 3;

/// Open a UDP socket that passively snoops DHCP client traffic. Clients broadcast
/// DISCOVER/REQUEST messages to the server port (67), so we bind `0.0.0.0:67` with
/// address/port reuse to coexist with any DHCP server/relay already on the host. DHCP is
/// broadcast rather than multicast, so there is no group to join.
pub fn open_socket() -> Result<UdpSocket, Box<dyn std::error::Error>> {
    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;
    socket.set_reuse_address(true)?;
    #[cfg(unix)]
    socket.set_reuse_port(true)?;
    socket.bind(&SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, DHCP_SERVER_PORT).into())?;
    socket.set_nonblocking(true)?;

    let udp = UdpSocket::from_std(socket.into())?;
    info!("DHCP listener bound to port {DHCP_SERVER_PORT}");
    Ok(udp)
}

/// The contents of a DHCP client request relevant to device discovery.
pub struct DhcpDiscovery {
    /// Client hardware (MAC) address taken directly from `chaddr` (e.g. `aa:bb:cc:dd:ee:ff`).
    pub mac: String,
    /// Host name advertised by option 12, if present.
    pub hostname: Option<String>,
    /// Best-effort client IP: `ciaddr` when bound/renewing, otherwise the requested IP
    /// (option 50). `None` for a fresh DISCOVER that carries neither.
    pub ip_hint: Option<Ipv4Addr>,
}

/// Parse a raw DHCP packet into a `DhcpDiscovery`. Returns `None` for anything that is not
/// an Ethernet client DISCOVER/REQUEST (server replies, non-Ethernet hardware, other
/// message types, or unparseable/truncated buffers).
pub fn parse_packet(buf: &[u8]) -> Option<DhcpDiscovery> {
    // Need the full fixed header plus the 4-byte magic cookie before any option.
    if buf.len() < OPTIONS_OFFSET {
        debug!("Ignoring short DHCP packet ({} bytes)", buf.len());
        return None;
    }

    // Only client requests over Ethernet carry a usable MAC in chaddr.
    if buf[OP_OFFSET] != OP_BOOTREQUEST
        || buf[HTYPE_OFFSET] != HTYPE_ETHERNET
        || buf[HLEN_OFFSET] != HLEN_ETHERNET
    {
        return None;
    }

    if buf[MAGIC_COOKIE_OFFSET..OPTIONS_OFFSET] != MAGIC_COOKIE {
        debug!("Ignoring DHCP packet with missing/invalid magic cookie");
        return None;
    }

    let mac = format_mac(&buf[CHADDR_OFFSET..CHADDR_OFFSET + 6]);

    let ciaddr = Ipv4Addr::new(
        buf[CIADDR_OFFSET],
        buf[CIADDR_OFFSET + 1],
        buf[CIADDR_OFFSET + 2],
        buf[CIADDR_OFFSET + 3],
    );

    let mut message_type: Option<u8> = None;
    let mut hostname: Option<String> = None;
    let mut requested_ip: Option<Ipv4Addr> = None;

    // Walk the TLV options. Each option is code(1) + len(1) + len bytes, except PAD (no
    // length) and END (terminates). Any malformed/truncated length stops the walk safely.
    let mut i = OPTIONS_OFFSET;
    while i < buf.len() {
        let code = buf[i];
        if code == OPTION_END {
            break;
        }
        if code == OPTION_PAD {
            i += 1;
            continue;
        }
        // Need a length byte and the advertised payload to be fully present.
        if i + 1 >= buf.len() {
            break;
        }
        let len = buf[i + 1] as usize;
        let value_start = i + 2;
        let value_end = value_start + len;
        if value_end > buf.len() {
            break;
        }
        let value = &buf[value_start..value_end];

        match code {
            OPTION_MESSAGE_TYPE => {
                if let Some(&t) = value.first() {
                    message_type = Some(t);
                }
            }
            OPTION_HOSTNAME => {
                if let Ok(name) = std::str::from_utf8(value) {
                    let name = name.trim_matches(char::from(0)).trim();
                    if !name.is_empty() {
                        hostname = Some(name.to_string());
                    }
                }
            }
            OPTION_REQUESTED_IP if value.len() == 4 => {
                requested_ip = Some(Ipv4Addr::new(value[0], value[1], value[2], value[3]));
            }
            _ => {}
        }

        i = value_end;
    }

    // Only DISCOVER/REQUEST signal "a client is asking for an address".
    match message_type {
        Some(DHCP_DISCOVER) | Some(DHCP_REQUEST) => {}
        _ => return None,
    }

    let ip_hint = if ciaddr != Ipv4Addr::UNSPECIFIED {
        Some(ciaddr)
    } else {
        requested_ip
    };

    Some(DhcpDiscovery {
        mac,
        hostname,
        ip_hint,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    // Build a minimal but valid DHCP packet: fixed header + magic cookie + options.
    fn build_packet(op: u8, htype: u8, hlen: u8, ciaddr: Ipv4Addr, options: &[u8]) -> Vec<u8> {
        let mut buf = vec![0u8; OPTIONS_OFFSET];
        buf[OP_OFFSET] = op;
        buf[HTYPE_OFFSET] = htype;
        buf[HLEN_OFFSET] = hlen;
        let ci = ciaddr.octets();
        buf[CIADDR_OFFSET..CIADDR_OFFSET + 4].copy_from_slice(&ci);
        // chaddr: aa:bb:cc:dd:ee:ff
        buf[CHADDR_OFFSET..CHADDR_OFFSET + 6]
            .copy_from_slice(&[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        buf[MAGIC_COOKIE_OFFSET..OPTIONS_OFFSET].copy_from_slice(&MAGIC_COOKIE);
        buf.extend_from_slice(options);
        buf.push(OPTION_END);
        buf
    }

    fn message_type_option(t: u8) -> Vec<u8> {
        vec![OPTION_MESSAGE_TYPE, 1, t]
    }

    #[test]
    fn test_parse_discover_with_hostname_and_requested_ip() {
        let mut options = message_type_option(DHCP_DISCOVER);
        options.extend_from_slice(&[OPTION_HOSTNAME, 6, b'l', b'a', b'p', b't', b'o', b'p']);
        options.extend_from_slice(&[OPTION_REQUESTED_IP, 4, 192, 168, 1, 50]);

        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        let parsed = parse_packet(&buf).expect("discover packet");
        assert_eq!(parsed.mac, "aa:bb:cc:dd:ee:ff");
        assert_eq!(parsed.hostname.as_deref(), Some("laptop"));
        assert_eq!(parsed.ip_hint, Some(Ipv4Addr::new(192, 168, 1, 50)));
    }

    #[test]
    fn test_parse_request_prefers_ciaddr_over_requested_ip() {
        let mut options = message_type_option(DHCP_REQUEST);
        options.extend_from_slice(&[OPTION_REQUESTED_IP, 4, 192, 168, 1, 50]);

        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::new(192, 168, 1, 99),
            &options,
        );
        let parsed = parse_packet(&buf).expect("request packet");
        assert_eq!(parsed.mac, "aa:bb:cc:dd:ee:ff");
        // ciaddr (bound/renewing) takes precedence over the requested-IP option.
        assert_eq!(parsed.ip_hint, Some(Ipv4Addr::new(192, 168, 1, 99)));
    }

    #[test]
    fn test_parse_discover_without_ip_yields_none_hint() {
        let options = message_type_option(DHCP_DISCOVER);
        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        let parsed = parse_packet(&buf).expect("discover packet");
        assert_eq!(parsed.mac, "aa:bb:cc:dd:ee:ff");
        assert_eq!(parsed.hostname, None);
        assert_eq!(parsed.ip_hint, None);
    }

    #[test]
    fn test_parse_server_reply_returns_none() {
        // op = 2 (BOOTREPLY) — a server message, ignored.
        let options = message_type_option(DHCP_DISCOVER);
        let buf = build_packet(
            2,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        assert!(parse_packet(&buf).is_none());
    }

    #[test]
    fn test_parse_other_message_type_returns_none() {
        // message type 5 = ACK (server->client), not a client request.
        let options = message_type_option(5);
        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        assert!(parse_packet(&buf).is_none());
    }

    #[test]
    fn test_parse_missing_message_type_returns_none() {
        // No option 53 present at all.
        let options = vec![OPTION_HOSTNAME, 4, b'h', b'o', b's', b't'];
        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        assert!(parse_packet(&buf).is_none());
    }

    #[test]
    fn test_parse_bad_magic_cookie_returns_none() {
        let options = message_type_option(DHCP_DISCOVER);
        let mut buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        buf[MAGIC_COOKIE_OFFSET] = 0;
        assert!(parse_packet(&buf).is_none());
    }

    #[test]
    fn test_parse_non_ethernet_returns_none() {
        let options = message_type_option(DHCP_DISCOVER);
        // htype != 1
        let buf = build_packet(
            OP_BOOTREQUEST,
            6,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        assert!(parse_packet(&buf).is_none());
        // hlen != 6
        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            8,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        assert!(parse_packet(&buf).is_none());
    }

    #[test]
    fn test_parse_truncated_and_garbage_returns_none() {
        assert!(parse_packet(&[0u8; 100]).is_none());
        assert!(parse_packet(&[0xff, 0x00, 0x13]).is_none());
    }

    #[test]
    fn test_parse_truncated_option_length_is_safe() {
        // Option claims 4 bytes of payload but the buffer ends early. Must not panic and
        // must not yield a discovery (message type never read).
        let options = vec![OPTION_REQUESTED_IP, 4, 192, 168];
        let buf = build_packet(
            OP_BOOTREQUEST,
            HTYPE_ETHERNET,
            HLEN_ETHERNET,
            Ipv4Addr::UNSPECIFIED,
            &options,
        );
        // Drop the trailing END byte appended by build_packet to keep the option truncated.
        let truncated = &buf[..buf.len() - 1];
        assert!(parse_packet(truncated).is_none());
    }
}
