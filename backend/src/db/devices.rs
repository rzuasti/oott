use chrono::{DateTime, Utc};
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::{
    db::{self, error::DbError},
    model::devices::Device,
};

pub fn list_devices(
    is_registered: Option<bool>,
    last_seen_from: Option<DateTime<Utc>>,
    last_seen_to: Option<DateTime<Utc>>,
    owner: Option<String>,
    device_type: Option<String>,
    vendor: Option<String>,
) -> Result<Vec<Device>, DbError> {
    debug!("Listing devices");
    let conn = db::get_db_connection();

    // Prepare SQL and parameters
    let mut sql_statement = "SELECT mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type FROM devices WHERE 1=1 ".to_string();
    let mut params: Vec<rusqlite::types::Value> = Vec::new();
    if let Some(is_registered) = is_registered {
        debug!("Adding filter is_registered={}", is_registered);
        sql_statement.push_str("AND is_registered=? ");
        params.push(is_registered.into());
    };
    if let Some(last_seen_from) = last_seen_from {
        debug!(
            "Adding filter last_seen>={}",
            last_seen_from.format("%Y-%m-%d %H:%M:%S")
        );
        sql_statement.push_str("AND last_seen>=? ");
        params.push(
            last_seen_from
                .format("%Y-%m-%d %H:%M:%S")
                .to_string()
                .into(),
        );
    };
    if let Some(last_seen_to) = last_seen_to {
        debug!(
            "Adding filter last_seen<={}",
            last_seen_to.format("%Y-%m-%d %H:%M:%S")
        );
        sql_statement.push_str("AND last_seen<=? ");
        params.push(
            last_seen_to
                .format("%Y-%m-%d %H:%M:%S")
                .to_string()
                .into(),
        );
    };
    if let Some(owner) = owner {
        debug!("Adding filter owner={}", owner);
        sql_statement.push_str("AND owner=? ");
        params.push(owner.into());
    };
    if let Some(device_type) = device_type {
        debug!("Adding filter device_type={}", device_type);
        sql_statement.push_str("AND device_type=? ");
        params.push(device_type.into());
    }
    if let Some(vendor) = vendor {
        debug!("Adding filter vendor={}", vendor);
        sql_statement.push_str("AND vendor=? ");
        params.push(vendor.into());
    }

    let mut stmt = conn.prepare(sql_statement.as_str())?;

    let devices: Vec<Device> = stmt
        .query_map(params_from_iter(params.iter()), |row| {
            Ok(Device {
                mac_address: row.get(0)?,
                ipv4_address: row.get(1)?,
                vendor: row.get(2)?,
                last_seen: row.get(3)?,
                is_registered: row.get(4)?,
                owner: row.get(5)?,
                device_type: row.get(6)?,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(devices)
}

// Read device from its MAC address
pub fn read(mac_address: String) -> Option<Device> {
    let conn = db::get_db_connection();

    let result: Result<Device, rusqlite::Error> = conn.query_one(
        "SELECT mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type FROM devices WHERE mac_address=?1",
        params![mac_address],
        |row| {
            Ok(Device {
                mac_address: row.get(0)?,
                ipv4_address: row.get(1)?,
                vendor: row.get(2)?,
                last_seen: row.get(3)?,
                is_registered: row.get(4)?,
                owner: row.get(5)?,
                device_type: row.get(6)?,
            })
        },
    );

    match result {
        Ok(value) => Some(value),
        Err(error) => {
            match error {
                rusqlite::Error::QueryReturnedNoRows => {
                    debug!("No device found for MAC address {mac_address}.")
                }
                _ => error!("Error reading device from database: {error}"),
            };
            None
        }
    }
}

pub fn insert(device: Device) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
        "INSERT INTO devices (mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![device.mac_address, device.ipv4_address, device.vendor, device.last_seen, device.is_registered, device.owner, device.device_type]) {
            Ok(_) => {
                debug!("Device inserted into database: {}", device);
                Ok(())
            },
            Err(error) => {
                error!("Error inserting device ({device}) into database: {error}");
                Err(DbError::from(error))
            },
    }
}

pub fn update(device: Device) -> Result<(), DbError> {
    let conn = db::get_db_connection();
    match conn.execute(
        "UPDATE devices SET ipv4_address=?1, vendor=?2, last_seen=?3, is_registered=?4, owner=?5, device_type=?6 WHERE mac_address=?7",
        params![
            device.ipv4_address,
            device.vendor,
            device.last_seen,
            device.is_registered,
            device.owner,
            device.device_type,
            device.mac_address,
        ],
    ) {
        Ok(_) => {
            debug!("Device updated in database: {}", device);
            Ok(())
        }
        Err(error) => {
            error!("Error updating device ({device}) in database: {error}");
            Err(DbError::from(error))
        }
    }
}

#[cfg(test)]
mod tests {
    use chrono::{DateTime, TimeZone, Utc};

    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn test_list() {
        tests_common::setup().await;

        // List all devices
        let devices: Vec<Device> = list_devices(None, None, None, None, None, None).unwrap();

        assert!(devices.len() >= 3, "There should be at least 3 devices");
        // Validate 1 device data
        let device = devices
            .iter()
            .filter(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
            .next()
            .unwrap();

        validate_device(
            device.clone(),
            "bb:bb:bb:bb:bb:bb".to_string(),
            "Phone".to_string(),
            "192.168.0.2".to_string(),
            true,
            Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
            "John".to_string(),
            "Vendor 2".to_string(),
        );

        // List registered devices
        let devices: Vec<Device> = list_devices(Some(true), None, None, None, None, None).unwrap();

        assert!(
            devices.len() >= 2,
            "There should be at least 2 registered devices"
        );
        // Device aa:aa:aa:aa:aa:aa should not be present
        assert!(
            devices
                .iter()
                .filter(|item| item.mac_address == "aa:aa:aa:aa:aa:aa")
                .next()
                .is_none(),
            "Device aa:aa:aa:aa:aa:aa should not be present"
        );

        // All devices should be registered
        assert!(
            devices
                .iter()
                .filter(|item| !item.is_registered)
                .next()
                .is_none(),
            "There should not be any non-registered devices"
        );

        // Validate 1 device
        let device = devices
            .iter()
            .filter(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
            .next()
            .unwrap();

        validate_device(
            device.clone(),
            "bb:bb:bb:bb:bb:bb".to_string(),
            "Phone".to_string(),
            "192.168.0.2".to_string(),
            true,
            Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
            "John".to_string(),
            "Vendor 2".to_string(),
        );

        // List devices seen in a time period - 2026-02-03 13:14:15
        let devices = list_devices(
            None,
            Some(Utc.with_ymd_and_hms(2026, 2, 2, 13, 13, 13).unwrap()),
            Some(Utc.with_ymd_and_hms(2026, 2, 4, 11, 11, 11).unwrap()),
            None,
            None,
            None,
        )
        .unwrap();

        assert!(devices.len() >= 1, "There should be at least one device");
        assert!(
            devices
                .iter()
                .filter(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
                .next()
                .is_some(),
            "Device bb:bb:bb:bb:bb:bb should be present"
        );
    }

    #[tokio::test]
    async fn test_update() {
        tests_common::setup().await;

        // Insert a device, update it and validate it

        let last_seen = Utc::now();
        insert(Device::new(
            "uu:tt:tt:tt:tt:aa".to_string(),
            "192.168.200.1".to_string(),
            "Test vendor".to_string(),
            last_seen,
        ))
        .unwrap();

        let mut device = read("uu:tt:tt:tt:tt:aa".to_string()).unwrap();
        device.is_registered = true;
        device.owner = "Grace".to_string();
        device.device_type = "Phone".to_string();

        update(device).unwrap();

        let device = read("uu:tt:tt:tt:tt:aa".to_string()).unwrap();

        validate_device(
            device,
            "uu:tt:tt:tt:tt:aa".to_string(),
            "Phone".to_string(),
            "192.168.200.1".to_string(),
            true,
            last_seen,
            "Grace".to_string(),
            "Test vendor".to_string(),
        );

        // Insert a device, change its MAC address and validate it hasnt changed (it cannot)
        let last_seen = Utc::now();
        insert(Device::new(
            "uu:tt:tt:tt:tt:bb".to_string(),
            "192.168.200.3".to_string(),
            "Test vendor".to_string(),
            last_seen,
        ))
        .unwrap();

        let mut device = read("uu:tt:tt:tt:tt:bb".to_string()).unwrap();
        device.mac_address = "uu:tt:tt:tt:tt:cc".to_string();

        update(device).unwrap();

        assert!(
            read("uu:tt:tt:tt:tt:cc".to_string()).is_none(),
            "Device should not exist"
        );

        assert!(
            read("uu:tt:tt:tt:tt:bb".to_string()).is_some(),
            "Device should exist"
        )
    }

    #[tokio::test]
    async fn test_insert() {
        tests_common::setup().await;

        // Insert constructed device and validate it
        let last_seen = Utc::now();
        insert(Device::new(
            "tt:tt:tt:tt:tt:aa".to_string(),
            "192.168.100.1".to_string(),
            "Test vendor".to_string(),
            last_seen,
        ))
        .unwrap();

        let device = read("tt:tt:tt:tt:tt:aa".to_string()).unwrap();
        validate_device(
            device,
            "tt:tt:tt:tt:tt:aa".to_string(),
            "".to_string(),
            "192.168.100.1".to_string(),
            false,
            last_seen,
            "".to_string(),
            "Test vendor".to_string(),
        );

        // Insert complete device and validate it
        let last_seen = Utc::now();
        insert(Device {
            mac_address: "tt:tt:tt:tt:tt:bb".to_string(),
            device_type: "Server".to_string(),
            ipv4_address: "192.168.100.2".to_string(),
            is_registered: true,
            last_seen: last_seen,
            owner: "Carl".to_string(),
            vendor: "Vendor X".to_string(),
        })
        .unwrap();

        let device = read("tt:tt:tt:tt:tt:bb".to_string()).unwrap();

        validate_device(
            device,
            "tt:tt:tt:tt:tt:bb".to_string(),
            "Server".to_string(),
            "192.168.100.2".to_string(),
            true,
            last_seen,
            "Carl".to_string(),
            "Vendor X".to_string(),
        );
    }

    #[tokio::test]
    async fn test_read() {
        tests_common::setup().await;
        // Read a non-existant device and validate for None
        assert!(
            read("zz:zz:zz:zz:zz:zz".to_string()).is_none(),
            "Device with MAC zz:zz:zz:zz:zz:zz should not exist"
        );

        // Read all testing devices and validate their values
        // 'aa:aa:aa:aa:aa:aa', '192.168.0.1', 'Vendor 1', '2026-01-01 11:11:11', 0, '', ''
        let device1 = read("aa:aa:aa:aa:aa:aa".to_string()).unwrap();
        validate_device(
            device1,
            "aa:aa:aa:aa:aa:aa".to_string(),
            "".to_string(),
            "192.168.0.1".to_string(),
            false,
            Utc.with_ymd_and_hms(2026, 1, 1, 11, 11, 11).unwrap(),
            "".to_string(),
            "Vendor 1".to_string(),
        );

        // 'bb:bb:bb:bb:bb:bb', '192.168.0.2', 'Vendor 2', '2026-02-03 13:14:15', 1, 'John', 'Phone'
        let device2 = read("bb:bb:bb:bb:bb:bb".to_string()).unwrap();
        validate_device(
            device2,
            "bb:bb:bb:bb:bb:bb".to_string(),
            "Phone".to_string(),
            "192.168.0.2".to_string(),
            true,
            Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
            "John".to_string(),
            "Vendor 2".to_string(),
        );

        // 'cc:cc:cc:cc:cc:cc', '192.168.0.3', 'Vendor 3', '2026-02-17 20:11:00', 1, 'Sarah', 'Laptop'
        let device3 = read("cc:cc:cc:cc:cc:cc".to_string()).unwrap();
        validate_device(
            device3,
            "cc:cc:cc:cc:cc:cc".to_string(),
            "Laptop".to_string(),
            "192.168.0.3".to_string(),
            true,
            Utc.with_ymd_and_hms(2026, 2, 17, 20, 11, 00).unwrap(),
            "Sarah".to_string(),
            "Vendor 3".to_string(),
        );
    }

    fn validate_device(
        device: Device,
        mac_address: String,
        device_type: String,
        ipv4_address: String,
        is_registered: bool,
        last_seen: DateTime<Utc>,
        owner: String,
        vendor: String,
    ) {
        assert_eq!(
            device.mac_address, mac_address,
            "Invalid MAC address for device {}",
            device.mac_address
        );
        assert_eq!(
            device.device_type, device_type,
            "Device type should be empty for device {}",
            device.mac_address
        );
        assert_eq!(
            device.ipv4_address, ipv4_address,
            "Invalid IP address for device {}",
            device.mac_address
        );
        assert_eq!(
            device.is_registered, is_registered,
            "Invalid registration status for device {}",
            device.mac_address
        );
        assert_eq!(
            device.last_seen, last_seen,
            "Invalid last_seen for device {}",
            device.mac_address
        );
        assert_eq!(
            device.owner, owner,
            "Invalid owner for device {}",
            device.mac_address
        );
        assert_eq!(
            device.vendor, vendor,
            "Invalid vendor for device {}",
            device.mac_address
        );
    }
}
