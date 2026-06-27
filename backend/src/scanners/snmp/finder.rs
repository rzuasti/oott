use std::collections::BTreeMap;
use std::net::{Ipv4Addr, SocketAddr};

use csnmp::{ObjectIdentifier, ObjectValue, Snmp2cClient};
use log::{debug, info, warn};

use crate::db;
use crate::model::devices::Device;
use crate::scanners::common::enrichment::build_device;
use crate::settings::SnmpScanner;
use crate::utils::network::format_mac;

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
    let pairs = dedup_by_mac(pairs, |mac| {
        db::devices::read(mac.to_string()).and_then(|d| d.ipv4_address.parse().ok())
    });

    let devices = pairs
        .into_iter()
        .map(|(mac, ip)| build_device(mac, ip.to_string(), &[], None))
        .collect();

    Ok(devices)
}

/// Collapse the parsed ARP rows so that each MAC yields a single `(mac, ipv4)` pair.
///
/// A router's neighbour cache can legitimately hold the same MAC at several IPs at once (e.g. a
/// device that changed address while the old entry has not yet aged out). Walking the table then
/// produces multiple rows for one MAC, and persisting each in turn makes the stored IP flap back
/// and forth, emitting a `DeviceChanged` every scan. Collapsing to one IP per MAC stops that.
///
/// `stored_ip` resolves a MAC to the IP OOTT currently has on record (`None` if the device is
/// unknown or its stored address is unparseable). The lookup is injected so this stays pure and
/// unit-testable; `find` supplies the database-backed version. Output is ordered by MAC (BTreeMap)
/// so it is deterministic.
fn dedup_by_mac<F>(pairs: Vec<(String, Ipv4Addr)>, stored_ip: F) -> Vec<(String, Ipv4Addr)>
where
    F: Fn(&str) -> Option<Ipv4Addr>,
{
    let mut by_mac: BTreeMap<String, Vec<Ipv4Addr>> = BTreeMap::new();
    for (mac, ip) in pairs {
        let ips = by_mac.entry(mac).or_default();
        if !ips.contains(&ip) {
            ips.push(ip);
        }
    }

    by_mac
        .into_iter()
        .map(|(mac, ips)| {
            let stored = stored_ip(&mac);
            let chosen = choose_ip(&ips, stored);
            if ips.len() > 1 {
                let reason = match stored {
                    Some(s) if s == chosen => "the IP already on record".to_string(),
                    Some(s) => format!("stored IP {s} no longer present, picked lowest"),
                    None => "device not yet known, picked lowest".to_string(),
                };
                debug!(
                    "Deduplicating device {mac}: seen at {} IPs this scan {ips:?}, keeping {chosen} ({reason})",
                    ips.len()
                );
            }
            (mac, chosen)
        })
        .collect()
}

/// Pick which IP to keep for a MAC seen at several IPs in one scan.
///
/// Prefer the IP OOTT already has stored, when it is among those found, so a known device stays
/// put and stops flapping. Otherwise fall back to the numerically lowest IP: a deterministic
/// choice that lets a new or genuinely-moved device settle on one value and converge on the next
/// scan. `candidates` is never empty.
fn choose_ip(candidates: &[Ipv4Addr], stored: Option<Ipv4Addr>) -> Ipv4Addr {
    if let Some(stored) = stored
        && candidates.contains(&stored)
    {
        return stored;
    }
    *candidates
        .iter()
        .min()
        .expect("a MAC group always has at least one IP")
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
            vec![(
                "aa:bb:cc:dd:ee:ff".to_string(),
                Ipv4Addr::new(192, 168, 1, 50)
            )]
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
        assert!(pairs.contains(&(
            "00:11:22:33:44:55".to_string(),
            Ipv4Addr::new(192, 168, 1, 2)
        )));
        assert!(pairs.contains(&(
            "66:77:88:99:aa:bb".to_string(),
            Ipv4Addr::new(192, 168, 1, 3)
        )));
    }

    fn ip(a: u8, b: u8, c: u8, d: u8) -> Ipv4Addr {
        Ipv4Addr::new(a, b, c, d)
    }

    const MAC: &str = "8c:16:45:bc:b2:79";

    #[test]
    fn keeps_stored_ip_when_mac_seen_at_several_ips() {
        let pairs = vec![
            (MAC.to_string(), ip(10, 10, 238, 249)),
            (MAC.to_string(), ip(10, 10, 2, 211)),
        ];
        // OOTT already has the device at 10.10.2.211, which is one of the two found.
        let deduped = dedup_by_mac(pairs, |_| Some(ip(10, 10, 2, 211)));
        assert_eq!(deduped, vec![(MAC.to_string(), ip(10, 10, 2, 211))]);
    }

    #[test]
    fn falls_back_to_lowest_ip_when_device_unknown() {
        let pairs = vec![
            (MAC.to_string(), ip(10, 10, 238, 249)),
            (MAC.to_string(), ip(10, 10, 2, 211)),
        ];
        let deduped = dedup_by_mac(pairs, |_| None);
        assert_eq!(deduped, vec![(MAC.to_string(), ip(10, 10, 2, 211))]);
    }

    #[test]
    fn falls_back_to_lowest_ip_when_stored_ip_no_longer_present() {
        let pairs = vec![
            (MAC.to_string(), ip(10, 10, 238, 249)),
            (MAC.to_string(), ip(10, 10, 2, 211)),
        ];
        // The device genuinely moved: its old stored IP is no longer in the table.
        let deduped = dedup_by_mac(pairs, |_| Some(ip(10, 10, 9, 9)));
        assert_eq!(deduped, vec![(MAC.to_string(), ip(10, 10, 2, 211))]);
    }

    #[test]
    fn single_ip_is_kept_regardless_of_stored_value() {
        let pairs = vec![(MAC.to_string(), ip(10, 10, 2, 211))];
        let deduped = dedup_by_mac(pairs, |_| Some(ip(10, 10, 9, 9)));
        assert_eq!(deduped, vec![(MAC.to_string(), ip(10, 10, 2, 211))]);
    }

    #[test]
    fn distinct_macs_are_each_retained() {
        let other = "00:11:22:33:44:55";
        let pairs = vec![
            (MAC.to_string(), ip(10, 10, 2, 211)),
            (other.to_string(), ip(10, 10, 1, 5)),
        ];
        let deduped = dedup_by_mac(pairs, |_| None);
        assert_eq!(deduped.len(), 2);
        assert!(deduped.contains(&(MAC.to_string(), ip(10, 10, 2, 211))));
        assert!(deduped.contains(&(other.to_string(), ip(10, 10, 1, 5))));
    }

    #[test]
    fn exact_duplicate_rows_collapse_to_one() {
        let pairs = vec![
            (MAC.to_string(), ip(10, 10, 2, 211)),
            (MAC.to_string(), ip(10, 10, 2, 211)),
        ];
        let deduped = dedup_by_mac(pairs, |_| None);
        assert_eq!(deduped, vec![(MAC.to_string(), ip(10, 10, 2, 211))]);
    }
}
