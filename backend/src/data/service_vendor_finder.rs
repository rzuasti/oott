use lazy_static::lazy_static;
use log::{debug, error, info};
use std::collections::HashMap;

// Initialize the mDNS service-type -> vendor database as a static lazy loaded unit
lazy_static! {
    static ref SERVICE_VENDOR_DATABASE: HashMap<String, String> = {
        info!("Loading mDNS service vendor database into memory");

        let data = include_str!("../../data/mdns-service-vendor.json");

        let raw: HashMap<String, String> = match serde_json::from_str(data) {
            Ok(value) => value,
            Err(error) => {
                error!(
                    "Error parsing mDNS service vendor database (data/mdns-service-vendor.json): {error}"
                );
                panic!(
                    "Error parsing mDNS service vendor database (data/mdns-service-vendor.json): {error}"
                );
            }
        };

        let database = raw
            .into_iter()
            .map(|(service, vendor)| (normalize(&service), vendor))
            .collect::<HashMap<String, String>>();

        debug!("Found {} records in the database", database.len());
        info!("mDNS service vendor database loaded");
        database
    };
}

// Normalize a service type for case- and trailing-dot-insensitive matching.
fn normalize(service_type: &str) -> String {
    service_type.trim_end_matches('.').to_lowercase()
}

/// Deduce a vendor from the mDNS service types a device advertises. Returns the vendor of the
/// first service type that matches a known vendor-specific signature, or an empty string if none
/// match.
pub fn find(service_types: &[String]) -> String {
    service_types
        .iter()
        .find_map(|service_type| SERVICE_VENDOR_DATABASE.get(&normalize(service_type)))
        .cloned()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_apple_service_returns_vendor() {
        let services = vec!["_companion-link._tcp.local".to_string()];
        assert_eq!(find(&services), "Apple, Inc.");
    }

    #[test]
    fn matching_is_case_and_trailing_dot_insensitive() {
        let services = vec!["_GoogleCast._tcp.local.".to_string()];
        assert_eq!(find(&services), "Google, Inc.");
    }

    #[test]
    fn first_matching_service_wins() {
        let services = vec![
            "_http._tcp.local".to_string(),
            "_sonos._tcp.local".to_string(),
        ];
        assert_eq!(find(&services), "Sonos, Inc.");
    }

    #[test]
    fn unknown_services_return_empty_string() {
        let services = vec![
            "_http._tcp.local".to_string(),
            "_ipp._tcp.local".to_string(),
        ];
        assert_eq!(find(&services), "");
    }

    #[test]
    fn empty_input_returns_empty_string() {
        assert_eq!(find(&[]), "");
    }
}
