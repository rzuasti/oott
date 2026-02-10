use lazy_static::lazy_static;
use log::{debug, error, info};
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct MacRecord {
    pub mac_prefix: String,
    pub vendor_name: String,
    // private: bool,
    // block_type: String,
    // last_update: String,
}

// Initialize mac vendors database as a static lazy loaded unit
lazy_static! {
    static ref MAC_VENDORS_DATABASE: HashMap<String, String> = {
        info!("Loading MAC vendor database into memory");

        let mut database = HashMap::new();
        let data = include_str!("../data/mac-vendors-export.json");

        let json: Vec<MacRecord> = match serde_json::from_str(&data) {
            Ok(value) => value,
            Err(error) => {
                error!(
                    "Error parsing mac vendors database (data/mac-vendors-export.json): {error}"
                );
                panic!(
                    "Error parsing mac vendors database (data/mac-vendors-export.json): {error}"
                );
            }
        };

        debug!("Found {} records in the database", json.len());

        for el in json {
            database.insert(el.mac_prefix.to_uppercase(), el.vendor_name);
        }

        info!("MAC vendor database loaded");
        database
    };
}

// Find a vendor based on the MAC prefix
pub fn find(mac_prefix: String) -> String {
    MAC_VENDORS_DATABASE
        .get(&mac_prefix.to_uppercase())
        .unwrap_or(&"".to_string())
        .to_string()
}
