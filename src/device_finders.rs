pub mod arp;

use chrono::NaiveDateTime;
use std::fmt;

#[derive(Clone)]
pub struct Device {
    pub mac_address: String,
    pub ipv4_address: String,
    pub vendor: String,
    pub last_seen: NaiveDateTime,
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
