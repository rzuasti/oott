use log::{debug, error};
use rusqlite::params;

use crate::{
    db::{self, error::DbError},
    model::devices::Device,
};

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
    use chrono::{TimeZone, Utc};

    use super::*;
    use crate::tests_common;

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
        assert_eq!(
            device1.mac_address, "aa:aa:aa:aa:aa:aa",
            "Invalid MAC address for device aa:aa:aa:aa:aa:aa"
        );
        assert_eq!(
            device1.device_type, "",
            "Device type should be empty for device {}",
            device1.mac_address
        );
        assert_eq!(
            device1.ipv4_address, "192.168.0.1",
            "Invalid IP address for device {}",
            device1.mac_address
        );
        assert!(
            !device1.is_registered,
            "Device {} should not be registered",
            device1.mac_address
        );
        assert_eq!(
            device1.last_seen,
            Utc.with_ymd_and_hms(2026, 1, 1, 11, 11, 11).unwrap(),
            "Invalid last_seen for device {}",
            device1.mac_address
        );
        assert_eq!(
            device1.owner, "",
            "Invalid owner for device {}",
            device1.mac_address
        );
        assert_eq!(
            device1.vendor, "Vendor 1",
            "Invalid vendor for device {}",
            device1.mac_address
        );

        // 'bb:bb:bb:bb:bb:bb', '192.168.0.2', 'Vendor 2', '2026-02-03 13:14:15', 1, 'John', 'Phone'
        let device2 = read("bb:bb:bb:bb:bb:bb".to_string()).unwrap();
        assert_eq!(
            device2.mac_address, "bb:bb:bb:bb:bb:bb",
            "Invalid MAC address for device bb:bb:bb:bb:bb:bb"
        );
        assert_eq!(
            device2.device_type, "Phone",
            "Device type should be 'Phone' for device {}",
            device2.mac_address
        );
        assert_eq!(
            device2.ipv4_address, "192.168.0.2",
            "Invalid IP address for device {}",
            device2.mac_address
        );
        assert!(
            device2.is_registered,
            "Device {} should not be registered",
            device2.mac_address
        );
        assert_eq!(
            device2.last_seen,
            Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
            "Invalid last_seen for device {}",
            device2.mac_address
        );
        assert_eq!(
            device2.owner, "John",
            "Invalid owner for device {}",
            device2.mac_address
        );
        assert_eq!(
            device2.vendor, "Vendor 2",
            "Invalid vendor for device {}",
            device2.mac_address
        );

        // 'cc:cc:cc:cc:cc:cc', '192.168.0.3', 'Vendor 3', '2026-02-17 20:11:00', 1, 'Sarah', 'Laptop'
        let device3 = read("cc:cc:cc:cc:cc:cc".to_string()).unwrap();
        assert_eq!(
            device3.mac_address, "cc:cc:cc:cc:cc:cc",
            "Invalid MAC address for device cc:cc:cc:cc:cc:cc"
        );
        assert_eq!(
            device3.device_type, "Laptop",
            "Device type should be 'Laptop' for device {}",
            device3.mac_address
        );
        assert_eq!(
            device3.ipv4_address, "192.168.0.3",
            "Invalid IP address for device {}",
            device3.mac_address
        );
        assert!(
            device3.is_registered,
            "Device {} should not be registered",
            device3.mac_address
        );
        assert_eq!(
            device3.last_seen,
            Utc.with_ymd_and_hms(2026, 2, 17, 20, 11, 00).unwrap(),
            "Invalid last_seen for device {}",
            device3.mac_address
        );
        assert_eq!(
            device3.owner, "Sarah",
            "Invalid owner for device {}",
            device3.mac_address
        );
        assert_eq!(
            device3.vendor, "Vendor 3",
            "Invalid vendor for device {}",
            device3.mac_address
        );
    }
}
