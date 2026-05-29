use chrono::{DateTime, Duration, Utc};
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::{
    db::{self, error::DbError},
    model::devices::{Device, DeviceSummary},
};

#[allow(clippy::too_many_arguments)]
pub fn list_devices(
    is_registered: Option<bool>,
    last_seen_from: Option<DateTime<Utc>>,
    last_seen_to: Option<DateTime<Utc>>,
    owner: Option<String>,
    device_type: Option<String>,
    vendor: Option<String>,
    page_offset: Option<i64>,
    page_limit: Option<i64>,
) -> Result<Vec<Device>, DbError> {
    debug!("Listing devices");
    let conn = db::get_db_connection();

    // Prepare SQL and parameters
    let mut sql_statement = "SELECT mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type, name FROM devices WHERE 1=1 ".to_string();
    let mut params: Vec<rusqlite::types::Value> = Vec::new();
    if let Some(is_registered) = is_registered {
        debug!("Adding filter is_registered={}", is_registered);
        sql_statement.push_str("AND is_registered=? ");
        params.push(is_registered.into());
    };
    if let Some(last_seen_from) = last_seen_from {
        debug!("Adding filter last_seen>={}", last_seen_from.to_rfc3339());
        sql_statement.push_str("AND last_seen>=? ");
        params.push(last_seen_from.to_rfc3339().into());
    };
    if let Some(last_seen_to) = last_seen_to {
        debug!("Adding filter last_seen<={}", last_seen_to.to_rfc3339());
        sql_statement.push_str("AND last_seen<=? ");
        params.push(last_seen_to.to_rfc3339().into());
    };
    if let Some(owner) = owner {
        debug!("Adding filter owner={}", owner);
        sql_statement.push_str("AND owner LIKE ? ");
        params.push(format!("%{}%", owner).into());
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

    // List order
    sql_statement.push_str("ORDER BY last_seen DESC ");

    // Paging
    if let (Some(page_offset), Some(page_limit)) = (page_offset, page_limit) {
        debug!(
            "Adding paging to list with offset={} and limit={}",
            page_offset, page_limit
        );
        sql_statement.push_str("LIMIT ? OFFSET ?");

        params.push(page_limit.into());
        params.push(page_offset.into());
    };

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
                name: row.get(7)?,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(devices)
}

// Read device from its MAC address
pub fn read(mac_address: String) -> Option<Device> {
    let conn = db::get_db_connection();

    let result: Result<Device, rusqlite::Error> = conn.query_one(
        "SELECT mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type, name FROM devices WHERE mac_address=?1",
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
                name: row.get(7)?,
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
        "INSERT INTO devices (mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type, name) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![device.mac_address, device.ipv4_address, device.vendor, device.last_seen.to_rfc3339_opts(chrono::SecondsFormat::Nanos, false), device.is_registered, device.owner, device.device_type, device.name]) {
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

pub fn get_summary() -> Result<DeviceSummary, DbError> {
    debug!("Getting device summary");
    let conn = db::get_db_connection();
    let one_day_ago = (Utc::now() - Duration::days(1)).to_rfc3339();
    let one_week_ago = (Utc::now() - Duration::weeks(1)).to_rfc3339();

    let total_registered: i64 = conn.query_row(
        "SELECT COUNT(*) FROM devices WHERE is_registered = 1",
        [],
        |row| row.get(0),
    )?;
    let seen_last_day_registered: i64 = conn.query_row(
        "SELECT COUNT(*) FROM devices WHERE last_seen >= ?1 AND is_registered = 1",
        params![one_day_ago],
        |row| row.get(0),
    )?;
    let seen_last_day_unregistered: i64 = conn.query_row(
        "SELECT COUNT(*) FROM devices WHERE last_seen >= ?1 AND is_registered = 0",
        params![one_day_ago],
        |row| row.get(0),
    )?;
    let seen_last_week_registered: i64 = conn.query_row(
        "SELECT COUNT(*) FROM devices WHERE last_seen >= ?1 AND is_registered = 1",
        params![one_week_ago],
        |row| row.get(0),
    )?;
    let seen_last_week_unregistered: i64 = conn.query_row(
        "SELECT COUNT(*) FROM devices WHERE last_seen >= ?1 AND is_registered = 0",
        params![one_week_ago],
        |row| row.get(0),
    )?;

    Ok(DeviceSummary {
        total_registered,
        seen_last_day_registered,
        seen_last_day_unregistered,
        seen_last_week_registered,
        seen_last_week_unregistered,
    })
}

pub fn update(device: Device) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    let mut sql = "UPDATE devices SET ipv4_address=?, last_seen=?, is_registered=?, owner=?".to_string();
    let mut params: Vec<rusqlite::types::Value> = vec![
        device.ipv4_address.clone().into(),
        device
            .last_seen
            .to_rfc3339_opts(chrono::SecondsFormat::Nanos, false)
            .into(),
        device.is_registered.into(),
        device.owner.clone().into(),
    ];

    // Only write the vendor (and its derived device_type) when deduced, so a sighting that
    // could not determine a vendor (empty string) never clobbers a previously known one.
    if !device.vendor.is_empty() {
        sql.push_str(", vendor=?, device_type=?");
        params.push(device.vendor.clone().into());
        params.push(device.device_type.clone().into());
    }

    // Only write the name column when it is set, so an ARP rescan (name: None) never
    // clobbers a hostname previously stored by the mDNS scanner.
    if let Some(name) = &device.name {
        sql.push_str(", name=?");
        params.push(name.clone().into());
    }

    sql.push_str(" WHERE mac_address=?");
    params.push(device.mac_address.clone().into());

    match conn.execute(sql.as_str(), params_from_iter(params.iter())) {
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
        let devices: Vec<Device> =
            list_devices(None, None, None, None, None, None, None, None).unwrap();

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
        let devices: Vec<Device> =
            list_devices(Some(true), None, None, None, None, None, None, None).unwrap();

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

        // Filter by owner substring - "oh" matches "John" but not "Sarah"
        let devices: Vec<Device> =
            list_devices(None, None, None, Some("oh".to_string()), None, None, None, None).unwrap();

        assert!(
            devices.len() >= 1,
            "There should be at least one device matching owner 'oh'"
        );
        assert!(
            devices
                .iter()
                .any(|item| item.mac_address == "bb:bb:bb:bb:bb:bb"),
            "Device bb:bb:bb:bb:bb:bb (John) should be present"
        );
        assert!(
            !devices
                .iter()
                .any(|item| item.mac_address == "cc:cc:cc:cc:cc:cc"),
            "Device cc:cc:cc:cc:cc:cc (Sarah) should not be present"
        );

        // List devices seen in a time period - 2026-02-03 13:14:15
        let devices = list_devices(
            None,
            Some(Utc.with_ymd_and_hms(2026, 2, 2, 13, 13, 13).unwrap()),
            Some(Utc.with_ymd_and_hms(2026, 2, 4, 11, 11, 11).unwrap()),
            None,
            None,
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
    async fn test_list_pagination() {
        tests_common::setup().await;

        // First page with 2 devices
        let first_page = list_devices(None, None, None, None, None, None, Some(0), Some(2)).unwrap();
        assert_eq!(first_page.len(), 2, "First page should have 2 devices");

        // Second page with 2 devices, should have at least 1 (seed data has >= 3 devices)
        let second_page =
            list_devices(None, None, None, None, None, None, Some(2), Some(2)).unwrap();
        assert!(
            !second_page.is_empty(),
            "Second page should have at least 1 device"
        );

        // Pages should not overlap
        assert!(
            !first_page
                .iter()
                .any(|d| second_page.iter().any(|s| s.mac_address == d.mac_address)),
            "First and second pages should not share devices"
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
    async fn test_update_name_set_and_preserve() {
        tests_common::setup().await;

        let last_seen = Utc::now();
        insert(Device::new(
            "nn:nn:nn:nn:nn:01".to_string(),
            "192.168.210.1".to_string(),
            "Test vendor".to_string(),
            last_seen,
        ))
        .unwrap();

        // ARP-style insert leaves name unset
        assert_eq!(read("nn:nn:nn:nn:nn:01".to_string()).unwrap().name, None);

        // mDNS sets the name
        let mut device = read("nn:nn:nn:nn:nn:01".to_string()).unwrap();
        device.name = Some("host.local".to_string());
        update(device).unwrap();
        assert_eq!(
            read("nn:nn:nn:nn:nn:01".to_string()).unwrap().name,
            Some("host.local".to_string())
        );

        // An ARP rescan (name: None) must NOT clobber the stored name
        let mut device = read("nn:nn:nn:nn:nn:01".to_string()).unwrap();
        device.name = None;
        device.ipv4_address = "192.168.210.99".to_string();
        update(device).unwrap();
        let device = read("nn:nn:nn:nn:nn:01".to_string()).unwrap();
        assert_eq!(device.name, Some("host.local".to_string()));
        assert_eq!(device.ipv4_address, "192.168.210.99".to_string());

        // A later mDNS sighting updates the name
        let mut device = read("nn:nn:nn:nn:nn:01".to_string()).unwrap();
        device.name = Some("renamed.local".to_string());
        update(device).unwrap();
        assert_eq!(
            read("nn:nn:nn:nn:nn:01".to_string()).unwrap().name,
            Some("renamed.local".to_string())
        );
    }

    #[tokio::test]
    async fn test_update_vendor_set_and_preserve() {
        tests_common::setup().await;

        let last_seen = Utc::now();
        insert(Device::new(
            "vv:vv:vv:vv:vv:01".to_string(),
            "192.168.220.1".to_string(),
            "Apple, Inc.".to_string(),
            last_seen,
        ))
        .unwrap();

        let mut device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        device.device_type = "phone".to_string();
        update(device).unwrap();

        // A re-sighting that could not deduce a vendor (empty) must NOT clobber the known one,
        // nor its derived device_type, but other fields still update.
        let mut device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        device.vendor = "".to_string();
        device.device_type = "".to_string();
        device.ipv4_address = "192.168.220.99".to_string();
        update(device).unwrap();
        let device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        assert_eq!(device.vendor, "Apple, Inc.".to_string());
        assert_eq!(device.device_type, "phone".to_string());
        assert_eq!(device.ipv4_address, "192.168.220.99".to_string());

        // A later sighting that deduces a different vendor updates both vendor and device_type.
        let mut device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        device.vendor = "Google, Inc.".to_string();
        device.device_type = "tablet".to_string();
        update(device).unwrap();
        let device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        assert_eq!(device.vendor, "Google, Inc.".to_string());
        assert_eq!(device.device_type, "tablet".to_string());
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
            name: None,
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

    #[tokio::test]
    async fn test_get_summary() {
        tests_common::setup().await;

        // Insert a registered device seen now
        insert(Device {
            mac_address: "su:mm:ar:y1:01:01".to_string(),
            ipv4_address: "192.168.50.1".to_string(),
            vendor: "Test".to_string(),
            last_seen: Utc::now(),
            is_registered: true,
            owner: "Test".to_string(),
            device_type: "Server".to_string(),
            name: None,
        })
        .unwrap();

        // Insert an unregistered device seen now
        insert(Device {
            mac_address: "su:mm:ar:y1:02:02".to_string(),
            ipv4_address: "192.168.50.2".to_string(),
            vendor: "Test".to_string(),
            last_seen: Utc::now(),
            is_registered: false,
            owner: "".to_string(),
            device_type: "".to_string(),
            name: None,
        })
        .unwrap();

        let summary = get_summary().unwrap();

        // bb and cc from seed data are registered, plus our new one
        assert!(
            summary.total_registered >= 3,
            "Should have at least 3 registered devices"
        );
        assert!(
            summary.seen_last_day_registered >= 1,
            "Should have at least 1 registered device seen in last day"
        );
        assert!(
            summary.seen_last_day_unregistered >= 1,
            "Should have at least 1 unregistered device seen in last day"
        );
        assert!(
            summary.seen_last_week_registered >= 1,
            "Should have at least 1 registered device seen in last week"
        );
        assert!(
            summary.seen_last_week_unregistered >= 1,
            "Should have at least 1 unregistered device seen in last week"
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
