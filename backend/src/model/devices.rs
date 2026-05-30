use crate::utils::date_serializer;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct DeviceSummary {
    pub total_registered: i64,
    pub seen_last_day_registered: i64,
    pub seen_last_day_unregistered: i64,
    pub seen_last_week_registered: i64,
    pub seen_last_week_unregistered: i64,
}

#[derive(Clone, Serialize, Deserialize, ToSchema)]
pub struct Device {
    pub mac_address: String,
    pub ipv4_address: String,
    pub vendor: String,
    #[serde(with = "date_serializer")]
    #[schema(value_type = String, format = DateTime)]
    pub last_seen: DateTime<Utc>,
    pub is_registered: bool,
    pub owner: String,
    pub device_type: String,
    /// Hostname discovered via mDNS/Bonjour. None for devices found only via ARP.
    pub name: Option<String>,
}

impl Device {
    pub fn new(
        mac_address: String,
        ipv4_address: String,
        vendor: String,
        last_seen: DateTime<Utc>,
    ) -> Self {
        Self {
            mac_address,
            ipv4_address,
            vendor,
            last_seen,
            is_registered: false,
            owner: "".to_string(),
            device_type: "".to_string(),
            name: None,
        }
    }
}

impl fmt::Display for Device {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "mac={}, ip={}, vendor={}, last_seen={}, is_registered={}, owner={}, device_type={}, name={}",
            self.mac_address,
            self.ipv4_address,
            self.vendor,
            self.last_seen,
            self.is_registered,
            self.owner,
            self.device_type,
            self.name.as_deref().unwrap_or("")
        )
    }
}

impl PartialEq for Device {
    fn eq(&self, other: &Self) -> bool {
        self.mac_address == other.mac_address
    }
}
