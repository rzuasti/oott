use crate::utils::date_serializer;
use chrono::{DateTime, Utc};
use rusqlite::types::{FromSql, FromSqlError, FromSqlResult, ToSql, ToSqlOutput, ValueRef};
use serde::{Deserialize, Serialize};
use std::{error::Error, fmt, str::FromStr};
use utoipa::ToSchema;

#[derive(Clone, Serialize, Deserialize, ToSchema)]
pub struct DeviceEvent {
    pub id: i64,
    pub mac_address: String,
    #[serde(with = "date_serializer")]
    #[schema(value_type = String, format = DateTime)]
    pub created_on: DateTime<Utc>,
    pub event_type: DeviceEventType,
    pub ipv4_address: String,
    pub vendor: String,
    pub scanner: DeviceEventScanner,
}

impl DeviceEvent {
    pub fn new(
        mac_address: String,
        created_on: DateTime<Utc>,
        event_type: DeviceEventType,
        ipv4_address: String,
        vendor: String,
        scanner: DeviceEventScanner,
    ) -> Self {
        Self {
            id: -1,
            mac_address,
            created_on,
            event_type,
            ipv4_address,
            vendor,
            scanner,
        }
    }
}

impl fmt::Display for DeviceEvent {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "id={}, mac_address={}, created_on={}, event_type={}, ipv4_address={}, vendor={}, scanner={}",
            self.id,
            self.mac_address,
            self.created_on,
            self.event_type,
            self.ipv4_address,
            self.vendor,
            self.scanner,
        )
    }
}

impl PartialEq for DeviceEvent {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, ToSchema)]
pub enum DeviceEventType {
    NewDevice,
    DeviceSeen,
}

impl fmt::Display for DeviceEventType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::NewDevice => write!(f, "NewDevice"),
            Self::DeviceSeen => write!(f, "DeviceSeen"),
        }
    }
}

#[derive(Debug)]
pub struct DeviceEventTypeParseError;

impl fmt::Display for DeviceEventTypeParseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error parsing device event type")
    }
}

impl Error for DeviceEventTypeParseError {}

impl FromStr for DeviceEventType {
    type Err = DeviceEventTypeParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "NewDevice" => Ok(DeviceEventType::NewDevice),
            "DeviceSeen" => Ok(DeviceEventType::DeviceSeen),
            _ => Err(DeviceEventTypeParseError),
        }
    }
}

impl ToSql for DeviceEventType {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(self.to_string().into())
    }
}

impl FromSql for DeviceEventType {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        value
            .as_str()?
            .parse()
            .map_err(|e| FromSqlError::Other(Box::new(e)))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, ToSchema)]
pub enum DeviceEventScanner {
    Arp,
    Mdns,
    Ssdp,
}

impl fmt::Display for DeviceEventScanner {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::Arp => write!(f, "ARP"),
            Self::Mdns => write!(f, "mDNS"),
            Self::Ssdp => write!(f, "SSDP"),
        }
    }
}

#[derive(Debug)]
pub struct DeviceEventScannerParseError;

impl fmt::Display for DeviceEventScannerParseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error parsing device event scanner")
    }
}

impl Error for DeviceEventScannerParseError {}

impl FromStr for DeviceEventScanner {
    type Err = DeviceEventScannerParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "ARP" => Ok(DeviceEventScanner::Arp),
            "mDNS" => Ok(DeviceEventScanner::Mdns),
            "SSDP" => Ok(DeviceEventScanner::Ssdp),
            _ => Err(DeviceEventScannerParseError),
        }
    }
}

impl ToSql for DeviceEventScanner {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(self.to_string().into())
    }
}

impl FromSql for DeviceEventScanner {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        value
            .as_str()?
            .parse()
            .map_err(|e| FromSqlError::Other(Box::new(e)))
    }
}
