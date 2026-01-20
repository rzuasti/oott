use log::{debug, info};
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;

pub struct MacVendorFinder {
    mac_vendors_database: HashMap<String, String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct MacRecord {
    pub mac_prefix: String,
    pub vendor_name: String,
    // private: bool,
    // block_type: String,
    // last_update: String,
}

impl MacVendorFinder {
    pub fn new() -> MacVendorFinder {
        info!("Loading MAC vendor database into memory");

        let mut database = HashMap::new();
        let data = fs::read_to_string("data/mac-vendors-export.json").unwrap();
        let json: Vec<MacRecord> = serde_json::from_str(&data).unwrap();

        debug!("Found {} records in the database", json.len());

        for el in json {
            database.insert(el.mac_prefix.to_uppercase(), el.vendor_name);
        }

        info!("MAC vendor database loaded");

        MacVendorFinder {
            mac_vendors_database: database,
        }
    }

    pub fn find(&mut self, mac_prefix: &str) -> Option<&String> {
        self.mac_vendors_database
            .get(mac_prefix.to_uppercase().as_str())
    }
}
