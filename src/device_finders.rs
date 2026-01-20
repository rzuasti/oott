pub mod arp;

use std::fmt;

pub struct Device {
    pub mac_address: String,
    pub ipv4_address: String,
    pub vendor: String,
}

impl Device {
    // pub fn get_mac_prefix(&self) -> String {
    //     self.mac_address.get(0..8).unwrap_or("").to_string()
    // }
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "mac={}, ip={}, vendor={}",
            self.mac_address, self.ipv4_address, self.vendor
        )
    }
}
