pub mod arp;

use std::fmt;

pub struct Device {
    pub mac_address: String,
    pub ipv4_address: String,
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "mac={}, ip={}", self.mac_address, self.ipv4_address)
    }
}
