use chrono::Local;

use crate::data::mac_vendor_finder;
use crate::data::service_vendor_finder;
use crate::data::vendor_device_type_finder;
use crate::model::devices::Device;
use crate::utils::network;

/// Build an enriched [`Device`] from a discovered MAC and IPv4 address, deducing its vendor and
/// device type.
///
/// The vendor is resolved from the MAC's OUI. Privacy/locally-administered MACs have no real OUI,
/// so when that lookup fails the vendor is taken from the device's advertised `service_hints`
/// (e.g. mDNS service types or SSDP NT URNs); pass an empty slice when the protocol offers none.
/// An empty IPv4 address is allowed (e.g. a DHCP DISCOVER carries no assigned address).
pub fn build_device(
    mac: String,
    ipv4: String,
    service_hints: &[String],
    name: Option<String>,
) -> Device {
    let mut vendor = mac_vendor_finder::find(mac.get(0..8).unwrap_or("").to_string());
    if vendor.is_empty() && network::is_locally_administered(&mac) {
        vendor = service_vendor_finder::find(service_hints);
    }

    let mut device = Device::new(mac, ipv4, vendor, Local::now().to_utc());
    device.device_type = vendor_device_type_finder::find(&device.vendor);
    device.name = name;
    device
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn privacy_mac_falls_back_to_service_vendor() {
        // A locally-administered (0x02 bit set) MAC has no real OUI, so the vendor is taken from
        // the advertised service hint instead.
        let services = vec!["_companion-link._tcp.local".to_string()];
        let device = build_device(
            "02:11:22:33:44:55".to_string(),
            "192.168.1.10".to_string(),
            &services,
            Some("my-host".to_string()),
        );

        assert_eq!(device.vendor, "Apple, Inc.");
        assert_eq!(device.mac_address, "02:11:22:33:44:55");
        assert_eq!(device.ipv4_address, "192.168.1.10");
        assert_eq!(device.name, Some("my-host".to_string()));
    }

    #[test]
    fn service_fallback_is_skipped_for_globally_administered_macs() {
        // The service hint would resolve to Apple, but the fallback only applies to
        // locally-administered MACs, so a globally administered one must not pick it up.
        let services = vec!["_companion-link._tcp.local".to_string()];
        let device = build_device(
            "00:11:22:33:44:55".to_string(),
            String::new(),
            &services,
            None,
        );

        assert_ne!(device.vendor, "Apple, Inc.");
        assert!(device.ipv4_address.is_empty());
        assert!(device.name.is_none());
    }
}
