use lazy_static::lazy_static;
use log::{debug, error, info};
use std::collections::HashMap;

// Initialize vendor device type database as a static lazy loaded unit
lazy_static! {
    static ref VENDOR_DEVICE_TYPE_DATABASE: HashMap<String, String> = {
        info!("Loading vendor device type database into memory");

        let data = include_str!("../data/vendor-device-type.json");

        let database: HashMap<String, String> = match serde_json::from_str(data) {
            Ok(value) => value,
            Err(error) => {
                error!(
                    "Error parsing vendor device type database (data/vendor-device-type.json): {error}"
                );
                panic!(
                    "Error parsing vendor device type database (data/vendor-device-type.json): {error}"
                );
            }
        };

        debug!("Found {} records in the database", database.len());
        info!("Vendor device type database loaded");
        database
    };
}

// Find a device type based on the vendor name
pub fn find(vendor: &str) -> String {
    VENDOR_DEVICE_TYPE_DATABASE
        .get(vendor)
        .unwrap_or(&"".to_string())
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_vendor_returns_device_type() {
        let result = find("Apple, Inc.");
        assert!(!result.is_empty(), "Expected a device type for Apple, Inc.");
    }

    #[test]
    fn unknown_vendor_returns_empty_string() {
        let result = find("This Vendor Does Not Exist XYZ");
        assert_eq!(result, "");
    }
}
