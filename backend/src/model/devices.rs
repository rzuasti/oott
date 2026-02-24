use chrono::{DateTime, Utc, serde::ts_seconds};
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Clone, Serialize, Deserialize)]
pub struct Device {
    pub mac_address: String,
    pub ipv4_address: String,
    pub vendor: String,
    #[serde(with = "ts_seconds")]
    pub last_seen: DateTime<Utc>,
    pub is_registered: bool,
    pub owner: String,
    pub device_type: String,
}

impl Device {
    pub fn new(
        mac_address: String,
        ipv4_address: String,
        vendor: String,
        last_seen: DateTime<Utc>,
    ) -> Self {
        Self {
            mac_address: mac_address,
            ipv4_address: ipv4_address,
            vendor: vendor,
            last_seen: last_seen,
            is_registered: false,
            owner: "".to_string(),
            device_type: "".to_string(),
        }
    }
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "mac={}, ip={}, vendor={}, last_seen={}, is_registered={}, owner={}, device_type={}",
            self.mac_address,
            self.ipv4_address,
            self.vendor,
            self.last_seen,
            self.is_registered,
            self.owner,
            self.device_type
        )
    }
}

impl PartialEq for Device {
    fn eq(&self, other: &Self) -> bool {
        self.mac_address == other.mac_address
    }
}
