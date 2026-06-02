use std::net::{Ipv4Addr, SocketAddr};

use chrono::Local;
use csnmp::{ObjectIdentifier, ObjectValue, Snmp2cClient};
use log::{debug, info, warn};

use crate::data::mac_vendor_finder;
use crate::data::vendor_device_type_finder;
use crate::model::devices::Device;
use crate::settings::SnmpScanner;

// ipNetToMediaPhysAddress (RFC 1213 MIB-II): maps interface + IPv4 address to a MAC. Walking
// this column yields one row per neighbour in the agent's ARP cache. Rows are indexed by
// `<ifIndex>.<a>.<b>.<c>.<d>`, so the last four sub-identifiers of each returned OID are the
// IPv4 address and the value is the 6-byte hardware address.
const IP_NET_TO_MEDIA_PHYS_ADDRESS: [u32; 10] = [1, 3, 6, 1, 2, 1, 4, 22, 1, 2];

// How many rows to request per GETBULK round-trip while walking the table.
const MAX_REPETITIONS: u32 = 20;

/// Poll the configured SNMP agent's ARP cache and return the discovered devices, enriched with
/// vendor and device-type information. Errors (unreachable agent, timeout, bad community) are
/// propagated so the caller can log and retry on the next cycle.
pub async fn find(config: &SnmpScanner) -> Result<Vec<Device>, Box<dyn std::error::Error>> {
    let target: SocketAddr = config.target.parse()?;
    let timeout = Some(config.timeout.into());

    debug!("Opening SNMP session to {target}");
    let client = Snmp2cClient::new(
        target,
        config.community.clone().into_bytes(),
        None, // bind address: let the OS choose
        timeout,
        0, // retries
    )
    .await?;

    let base = ObjectIdentifier::try_from(&IP_NET_TO_MEDIA_PHYS_ADDRESS[..])?;
    let rows = client.walk_bulk(base, MAX_REPETITIONS).await?;
    info!("SNMP ARP table walk returned {} rows", rows.len());

    let pairs = parse_arp_table(rows.iter(), &base);

    let devices = pairs
        .into_iter()
        .map(|(mac, ip)| {
            let vendor = mac_vendor_finder::find(mac.get(0..8).unwrap_or("").to_string());
            let mut device = Device::new(mac, ip.to_string(), vendor, Local::now().to_utc());
            device.device_type = vendor_device_type_finder::find(&device.vendor);
            device
        })
        .collect();

    Ok(devices)
}

/// Decode the rows of an `ipNetToMediaPhysAddress` walk into `(mac, ipv4)` pairs.
///
/// Kept separate from the network I/O so it can be unit-tested with synthetic rows. Each row's
/// OID is `base.<ifIndex>.<a>.<b>.<c>.<d>`; the last four sub-identifiers form the IPv4 address
/// and the value is the 6-byte MAC. Rows that don't match this shape (wrong suffix length,
/// out-of-range octets, non-string or wrong-length value) are skipped.
pub fn parse_arp_table<'a, I>(rows: I, base: &ObjectIdentifier) -> Vec<(String, Ipv4Addr)>
where
    I: IntoIterator<Item = (&'a ObjectIdentifier, &'a ObjectValue)>,
{
    let mut pairs = Vec::new();

    for (oid, value) in rows {
        let suffix = match oid.relative_to(base) {
            Some(s) => s,
            None => continue, // not under the table base
        };
        let parts = suffix.as_slice();
        if parts.len() < 4 {
            continue;
        }

        // The IPv4 address is the last four sub-identifiers of the index.
        let octets = &parts[parts.len() - 4..];
        if octets.iter().any(|o| *o > 255) {
            warn!("Ignoring SNMP ARP row with out-of-range IP octet: {octets:?}");
            continue;
        }
        let ip = Ipv4Addr::new(
            octets[0] as u8,
            octets[1] as u8,
            octets[2] as u8,
            octets[3] as u8,
        );

        let mac = match value {
            ObjectValue::String(bytes) if bytes.len() == 6 => format_mac(bytes),
            _ => {
                debug!("Ignoring SNMP ARP row for {ip} with non-MAC value");
                continue;
            }
        };

        pairs.push((mac, ip));
    }

    pairs
}

/// Format 6 raw MAC bytes as a lowercase colon-separated string.
fn format_mac(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect::<Vec<_>>()
        .join(":")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn base() -> ObjectIdentifier {
        ObjectIdentifier::try_from(&IP_NET_TO_MEDIA_PHYS_ADDRESS[..]).unwrap()
    }

    /// Build a full row OID: base + ifIndex + four IP octets.
    fn row_oid(if_index: u32, ip: [u32; 4]) -> ObjectIdentifier {
        let mut parts = IP_NET_TO_MEDIA_PHYS_ADDRESS.to_vec();
        parts.push(if_index);
        parts.extend_from_slice(&ip);
        ObjectIdentifier::try_from(&parts[..]).unwrap()
    }

    fn mac_value(bytes: [u8; 6]) -> ObjectValue {
        ObjectValue::String(bytes.to_vec())
    }

    #[test]
    fn parses_a_valid_arp_row() {
        let oid = row_oid(2, [192, 168, 1, 50]);
        let value = mac_value([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        let rows = vec![(&oid, &value)];

        let pairs = parse_arp_table(rows, &base());
        assert_eq!(
            pairs,
            vec![("aa:bb:cc:dd:ee:ff".to_string(), Ipv4Addr::new(192, 168, 1, 50))]
        );
    }

    #[test]
    fn skips_rows_with_wrong_mac_length() {
        let oid = row_oid(1, [10, 0, 0, 1]);
        let value = ObjectValue::String(vec![0x01, 0x02, 0x03]); // too short
        let rows = vec![(&oid, &value)];
        assert!(parse_arp_table(rows, &base()).is_empty());
    }

    #[test]
    fn skips_non_string_values() {
        let oid = row_oid(1, [10, 0, 0, 1]);
        let value = ObjectValue::Integer(42);
        let rows = vec![(&oid, &value)];
        assert!(parse_arp_table(rows, &base()).is_empty());
    }

    #[test]
    fn skips_rows_outside_the_table_base() {
        // An OID that is not under the table base must be ignored.
        let unrelated = ObjectIdentifier::try_from(&[1u32, 3, 6, 1, 2, 1, 1, 1, 0][..]).unwrap();
        let value = mac_value([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        let rows = vec![(&unrelated, &value)];
        assert!(parse_arp_table(rows, &base()).is_empty());
    }

    #[test]
    fn parses_multiple_rows() {
        let oid_a = row_oid(1, [192, 168, 1, 2]);
        let val_a = mac_value([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        let oid_b = row_oid(1, [192, 168, 1, 3]);
        let val_b = mac_value([0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb]);
        let rows = vec![(&oid_a, &val_a), (&oid_b, &val_b)];

        let pairs = parse_arp_table(rows, &base());
        assert_eq!(pairs.len(), 2);
        assert!(pairs.contains(&("00:11:22:33:44:55".to_string(), Ipv4Addr::new(192, 168, 1, 2))));
        assert!(pairs.contains(&("66:77:88:99:aa:bb".to_string(), Ipv4Addr::new(192, 168, 1, 3))));
    }

    #[test]
    fn format_mac_pads_and_lowercases() {
        assert_eq!(format_mac(&[0x0a, 0x00, 0xff, 0x10, 0x20, 0x30]), "0a:00:ff:10:20:30");
    }
}
