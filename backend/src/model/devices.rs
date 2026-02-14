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
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "mac={}, ip={}, vendor={}, last_seen={}",
            self.mac_address, self.ipv4_address, self.vendor, self.last_seen
        )
    }
}
