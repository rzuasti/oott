use log::{debug, error};
use rusqlite::{Connection, params};
use std::sync::MutexGuard;

use crate::device_finders::Device;

// Read device from its MAC address
pub fn read(conn: MutexGuard<Connection>, mac_address: String) -> Option<Device> {
    // TODO: Add last_seen
    let result: Result<Device, rusqlite::Error> = conn.query_one(
        "SELECT mac_address, ipv4_address, vendor, last_seen FROM devices WHERE mac_address=?1",
        params![mac_address],
        |row| {
            Ok(Device {
                mac_address: row.get(0)?,
                ipv4_address: row.get(1)?,
                vendor: row.get(2)?,
                last_seen: row.get(3)?,
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

pub fn insert(conn: MutexGuard<Connection>, device: Device) -> Result<(), String> {
    match conn.execute(
        "INSERT INTO devices (mac_address, ipv4_address, vendor, last_seen) VALUES (?1, ?2, ?3, ?4)",
        params![device.mac_address, device.ipv4_address, device.vendor, device.last_seen]) {
            Ok(_) => {
                debug!("Device inserted into database: {}", device);
                Ok(())
            },
            Err(error) => {
                error!("Error inserting device ({device}) into database: {error}");
                Err(format!("Error inserting device ({device}) into database: {error}").to_string())
            },
    }
}

pub fn update(conn: MutexGuard<Connection>, device: Device) -> Result<(), String> {
    match conn.execute(
        "UPDATE devices SET ipv4_address=?1, vendor=?2, last_seen=?3 WHERE mac_address=?4",
        params![
            device.ipv4_address,
            device.vendor,
            device.last_seen,
            device.mac_address
        ],
    ) {
        Ok(_) => {
            debug!("Device updated in database: {}", device);
            Ok(())
        }
        Err(error) => {
            error!("Error updating device ({device}) in database: {error}");
            Err(format!("Error updating device ({device}) in database: {error}").to_string())
        }
    }
}
