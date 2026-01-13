pub mod arp;

use std::fmt;

pub struct Device {
    pub mac_address: String,
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "mac={}", self.mac_address)
    }
}
