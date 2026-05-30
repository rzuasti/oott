use chrono::{DateTime, Duration, Utc};
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::{
    db::{self, error::DbError},
    model::devices::{Device, DeviceSummary},
};

// Whitelist of columns allowed for `sort_by`. Anything outside this list falls back to the
// default. Kept here so the API handler doesn't have to know about SQL column names.
fn resolve_sort_column(sort_by: Option<&str>) -> &'static str {
    match sort_by.map(|s| s.to_ascii_lowercase()).as_deref() {
        Some("name") => "name",
        Some("owner") => "owner",
        Some("mac_address") => "mac_address",
        Some("ipv4_address") => "ipv4_address",
        Some("vendor") => "vendor",
        Some("is_registered") => "is_registered",
        Some("device_type") => "device_type",
        _ => "last_seen",
    }
}

fn resolve_sort_direction(sort_order: Option<&str>) -> &'static str {
    match sort_order.map(|s| s.to_ascii_lowercase()).as_deref() {
        Some("asc") => "ASC",
        _ => "DESC",
    }
}

#[allow(clippy::too_many_arguments)]
pub fn list_devices(
    is_registered: Option<bool>,
    last_seen_from: Option<DateTime<Utc>>,
    last_seen_to: Option<DateTime<Utc>>,
    owner: Option<String>,
    device_type: Option<String>,
    vendor: Option<String>,
    sort_by: Option<String>,
    sort_order: Option<String>,
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

    // List order — both column and direction are validated against a whitelist so user input
    // is never interpolated raw. A secondary `mac_address ASC` keeps paging deterministic when
    // the primary sort key ties.
    let sort_column = resolve_sort_column(sort_by.as_deref());
    let sort_direction = resolve_sort_direction(sort_order.as_deref());
    sql_statement.push_str(&format!(
        "ORDER BY {} {}, mac_address ASC ",
        sort_column, sort_direction
    ));

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

// Records a sighting of an existing device by a scanner. last_seen is stamped here with the
// current time. Registration fields (is_registered, owner) are owned by register/unregister
// and are intentionally never touched here.
pub fn seen(
    mac_address: String,
    ipv4_address: String,
    vendor: String,
    device_type: String,
    name: Option<String>,
) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    let mut sql = "UPDATE devices SET ipv4_address=?, last_seen=?".to_string();
    let mut params: Vec<rusqlite::types::Value> = vec![
        ipv4_address.into(),
        Utc::now()
            .to_rfc3339_opts(chrono::SecondsFormat::Nanos, false)
            .into(),
    ];

    // Only write the vendor (and its derived device_type) when deduced, so a sighting that
    // could not determine a vendor (empty string) never clobbers a previously known one.
    // device_type is only written when the stored value is empty, so a value chosen by the
    // user (via register) or previously deduced is never overwritten by a later sighting.
    if !vendor.is_empty() {
        sql.push_str(
            ", vendor=?, device_type=CASE WHEN device_type='' THEN ? ELSE device_type END",
        );
        params.push(vendor.into());
        params.push(device_type.into());
    }

    // Only write the name column when it is set, so an ARP rescan (name: None) never
    // clobbers a hostname previously stored by the mDNS scanner.
    if let Some(name) = name {
        sql.push_str(", name=?");
        params.push(name.into());
    }

    sql.push_str(" WHERE mac_address=?");
    params.push(mac_address.clone().into());

    match conn.execute(sql.as_str(), params_from_iter(params.iter())) {
        Ok(_) => {
            debug!("Device sighting recorded in database: {mac_address}");
            Ok(())
        }
        Err(error) => {
            error!("Error recording device sighting ({mac_address}) in database: {error}");
            Err(DbError::from(error))
        }
    }
}

// Modifies user-editable fields of a device. Intended for the UI's "modify" feature; scanners
// must use seen() instead.
pub fn update(
    mac_address: String,
    owner: String,
    device_type: String,
    vendor: String,
) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
        "UPDATE devices SET owner=?1, device_type=?2, vendor=?3 WHERE mac_address=?4",
        params![owner, device_type, vendor, mac_address],
    ) {
        Ok(_) => {
            debug!("Device updated in database: {mac_address}");
            Ok(())
        }
        Err(error) => {
            error!("Error updating device ({mac_address}) in database: {error}");
            Err(DbError::from(error))
        }
    }
}

pub fn register(
    mac_address: String,
    owner: String,
    device_type: String,
    name: Option<String>,
) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    // Only write the name column when supplied, so a user registering without typing a name
    // never wipes a hostname previously stored by the mDNS scanner.
    let mut sql = "UPDATE devices SET is_registered=1, owner=?, device_type=?".to_string();
    let mut params: Vec<rusqlite::types::Value> = vec![owner.into(), device_type.into()];
    if let Some(name) = name {
        sql.push_str(", name=?");
        params.push(name.into());
    }
    sql.push_str(" WHERE mac_address=?");
    params.push(mac_address.clone().into());

    match conn.execute(sql.as_str(), params_from_iter(params.iter())) {
        Ok(_) => {
            debug!("Device registered in database: {mac_address}");
            Ok(())
        }
        Err(error) => {
            error!("Error registering device ({mac_address}) in database: {error}");
            Err(DbError::from(error))
        }
    }
}

pub fn unregister(mac_address: String) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
        "UPDATE devices SET is_registered=0, owner='' WHERE mac_address=?1",
        params![mac_address],
    ) {
        Ok(_) => {
            debug!("Device unregistered in database: {mac_address}");
            Ok(())
        }
        Err(error) => {
            error!("Error unregistering device ({mac_address}) in database: {error}");
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
    async fn test_list() {
        tests_common::setup().await;

        // List all devices
        let devices: Vec<Device> =
            list_devices(None, None, None, None, None, None, None, None, None, None).unwrap();

        assert!(devices.len() >= 3, "There should be at least 3 devices");
        // Validate 1 device data
        let device = devices
            .iter().find(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
            .unwrap();

        validate_device(
            device,
            &Device {
                mac_address: "bb:bb:bb:bb:bb:bb".to_string(),
                device_type: "Phone".to_string(),
                ipv4_address: "192.168.0.2".to_string(),
                is_registered: true,
                last_seen: Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
                owner: "John".to_string(),
                vendor: "Vendor 2".to_string(),
                name: None,
            },
        );

        // List registered devices
        let devices: Vec<Device> =
            list_devices(Some(true), None, None, None, None, None, None, None, None, None)
                .unwrap();

        assert!(
            devices.len() >= 2,
            "There should be at least 2 registered devices"
        );
        // Device aa:aa:aa:aa:aa:aa should not be present
        assert!(
            devices
                .iter().find(|item| item.mac_address == "aa:aa:aa:aa:aa:aa")
                .is_none(),
            "Device aa:aa:aa:aa:aa:aa should not be present"
        );

        // All devices should be registered
        assert!(
            devices
                .iter().find(|item| !item.is_registered)
                .is_none(),
            "There should not be any non-registered devices"
        );

        // Validate 1 device
        let device = devices
            .iter().find(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
            .unwrap();

        validate_device(
            device,
            &Device {
                mac_address: "bb:bb:bb:bb:bb:bb".to_string(),
                device_type: "Phone".to_string(),
                ipv4_address: "192.168.0.2".to_string(),
                is_registered: true,
                last_seen: Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
                owner: "John".to_string(),
                vendor: "Vendor 2".to_string(),
                name: None,
            },
        );

        // Filter by owner substring - "oh" matches "John" but not "Sarah"
        let devices: Vec<Device> = list_devices(
            None,
            None,
            None,
            Some("oh".to_string()),
            None,
            None,
            None,
            None,
            None,
            None,
        )
        .unwrap();

        assert!(
            !devices.is_empty(),
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
            None,
            None,
        )
        .unwrap();

        assert!(!devices.is_empty(), "There should be at least one device");
        assert!(
            devices
                .iter().find(|item| item.mac_address == "bb:bb:bb:bb:bb:bb")
                .is_some(),
            "Device bb:bb:bb:bb:bb:bb should be present"
        );
    }

    #[tokio::test]
    async fn test_list_sorting() {
        tests_common::setup().await;

        // Sort by mac_address ascending — first result should have the smallest MAC.
        let by_mac_asc = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            Some("mac_address".to_string()),
            Some("asc".to_string()),
            None,
            None,
        )
        .unwrap();
        assert!(by_mac_asc.len() >= 3);
        let macs_asc: Vec<&str> = by_mac_asc.iter().map(|d| d.mac_address.as_str()).collect();
        let mut sorted_macs = macs_asc.clone();
        sorted_macs.sort();
        assert_eq!(macs_asc, sorted_macs, "mac_address asc should be sorted");

        // Sort by mac_address descending — same list, reversed.
        let by_mac_desc = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            Some("mac_address".to_string()),
            Some("desc".to_string()),
            None,
            None,
        )
        .unwrap();
        let macs_desc: Vec<&str> = by_mac_desc.iter().map(|d| d.mac_address.as_str()).collect();
        let mut sorted_macs_desc = macs_desc.clone();
        sorted_macs_desc.sort_by(|a, b| b.cmp(a));
        assert_eq!(macs_desc, sorted_macs_desc, "mac_address desc should be sorted reversed");

        // Sort by owner ascending — empty-string owners (unregistered) come first lexically.
        let by_owner_asc = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            Some("owner".to_string()),
            Some("asc".to_string()),
            None,
            None,
        )
        .unwrap();
        let owners: Vec<&str> = by_owner_asc.iter().map(|d| d.owner.as_str()).collect();
        let mut sorted_owners = owners.clone();
        sorted_owners.sort();
        assert_eq!(owners, sorted_owners, "owner asc should be sorted");

        // Invalid sort_by falls back to default (last_seen DESC).
        let invalid = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            Some("drop_table".to_string()),
            None,
            None,
            None,
        )
        .unwrap();
        let default_sorted = list_devices(None, None, None, None, None, None, None, None, None, None).unwrap();
        let invalid_macs: Vec<&str> = invalid.iter().map(|d| d.mac_address.as_str()).collect();
        let default_macs: Vec<&str> = default_sorted.iter().map(|d| d.mac_address.as_str()).collect();
        assert_eq!(
            invalid_macs, default_macs,
            "invalid sort_by must fall back to the default ordering"
        );
    }

    #[tokio::test]
    async fn test_list_pagination() {
        tests_common::setup().await;

        // First page with 2 devices
        let first_page = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            Some(0),
            Some(2),
        )
        .unwrap();
        assert_eq!(first_page.len(), 2, "First page should have 2 devices");

        // Second page with 2 devices, should have at least 1 (seed data has >= 3 devices)
        let second_page = list_devices(
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            Some(2),
            Some(2),
        )
        .unwrap();
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
    async fn test_seen() {
        tests_common::setup().await;

        // Insert a device, record a sighting and validate it

        let initial_last_seen = Utc.with_ymd_and_hms(2020, 1, 1, 0, 0, 0).unwrap();
        insert(Device::new(
            "uu:tt:tt:tt:tt:aa".to_string(),
            "192.168.200.1".to_string(),
            "Test vendor".to_string(),
            initial_last_seen,
        ))
        .unwrap();

        // Register the device, then record a sighting. seen() must NOT clobber the
        // registration while still refreshing sighting fields (ipv4_address, last_seen).
        register(
            "uu:tt:tt:tt:tt:aa".to_string(),
            "Grace".to_string(),
            "Phone".to_string(),
            None,
        )
        .unwrap();

        let before = Utc::now();
        seen(
            "uu:tt:tt:tt:tt:aa".to_string(),
            "192.168.200.50".to_string(),
            "Test vendor".to_string(),
            "".to_string(),
            None,
        )
        .unwrap();

        let device = read("uu:tt:tt:tt:tt:aa".to_string()).unwrap();
        assert_eq!(device.ipv4_address, "192.168.200.50".to_string());
        assert!(
            device.last_seen >= before,
            "seen() should stamp last_seen with the current time"
        );
        assert!(device.is_registered);
        assert_eq!(device.owner, "Grace".to_string());
        assert_eq!(device.device_type, "Phone".to_string());
        assert_eq!(device.vendor, "Test vendor".to_string());

        // A seen() call for a MAC that doesn't exist is a no-op (no row matches)
        seen(
            "uu:tt:tt:tt:tt:cc".to_string(),
            "192.168.200.99".to_string(),
            "Test vendor".to_string(),
            "".to_string(),
            None,
        )
        .unwrap();
        assert!(
            read("uu:tt:tt:tt:tt:cc".to_string()).is_none(),
            "seen() must not insert new devices"
        );
    }

    #[tokio::test]
    async fn test_seen_name_set_and_preserve() {
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
        seen(
            "nn:nn:nn:nn:nn:01".to_string(),
            "192.168.210.1".to_string(),
            "Test vendor".to_string(),
            "".to_string(),
            Some("host.local".to_string()),
        )
        .unwrap();
        assert_eq!(
            read("nn:nn:nn:nn:nn:01".to_string()).unwrap().name,
            Some("host.local".to_string())
        );

        // An ARP rescan (name: None) must NOT clobber the stored name
        seen(
            "nn:nn:nn:nn:nn:01".to_string(),
            "192.168.210.99".to_string(),
            "Test vendor".to_string(),
            "".to_string(),
            None,
        )
        .unwrap();
        let device = read("nn:nn:nn:nn:nn:01".to_string()).unwrap();
        assert_eq!(device.name, Some("host.local".to_string()));
        assert_eq!(device.ipv4_address, "192.168.210.99".to_string());

        // A later mDNS sighting updates the name
        seen(
            "nn:nn:nn:nn:nn:01".to_string(),
            "192.168.210.99".to_string(),
            "Test vendor".to_string(),
            "".to_string(),
            Some("renamed.local".to_string()),
        )
        .unwrap();
        assert_eq!(
            read("nn:nn:nn:nn:nn:01".to_string()).unwrap().name,
            Some("renamed.local".to_string())
        );
    }

    #[tokio::test]
    async fn test_seen_vendor_set_and_preserve() {
        tests_common::setup().await;

        let last_seen = Utc::now();
        insert(Device::new(
            "vv:vv:vv:vv:vv:01".to_string(),
            "192.168.220.1".to_string(),
            "Apple, Inc.".to_string(),
            last_seen,
        ))
        .unwrap();

        seen(
            "vv:vv:vv:vv:vv:01".to_string(),
            "192.168.220.1".to_string(),
            "Apple, Inc.".to_string(),
            "phone".to_string(),
            None,
        )
        .unwrap();

        // A re-sighting that could not deduce a vendor (empty) must NOT clobber the known one,
        // nor its derived device_type, but other fields still update.
        seen(
            "vv:vv:vv:vv:vv:01".to_string(),
            "192.168.220.99".to_string(),
            "".to_string(),
            "".to_string(),
            None,
        )
        .unwrap();
        let device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        assert_eq!(device.vendor, "Apple, Inc.".to_string());
        assert_eq!(device.device_type, "phone".to_string());
        assert_eq!(device.ipv4_address, "192.168.220.99".to_string());

        // A later sighting that deduces a different vendor updates vendor but must NOT
        // overwrite a device_type that is already set.
        seen(
            "vv:vv:vv:vv:vv:01".to_string(),
            "192.168.220.99".to_string(),
            "Google, Inc.".to_string(),
            "tablet".to_string(),
            None,
        )
        .unwrap();
        let device = read("vv:vv:vv:vv:vv:01".to_string()).unwrap();
        assert_eq!(device.vendor, "Google, Inc.".to_string());
        assert_eq!(device.device_type, "phone".to_string());
    }

    #[tokio::test]
    async fn test_seen_preserves_registered_device_type() {
        tests_common::setup().await;

        // A device registered with a user-chosen device_type must not have it overwritten
        // by a later sighting that deduces a different device_type from a new vendor.
        let last_seen = Utc::now();
        insert(Device::new(
            "pp:pp:pp:pp:pp:01".to_string(),
            "192.168.240.1".to_string(),
            "".to_string(),
            last_seen,
        ))
        .unwrap();

        register(
            "pp:pp:pp:pp:pp:01".to_string(),
            "Grace".to_string(),
            "Laptop".to_string(),
            None,
        )
        .unwrap();

        seen(
            "pp:pp:pp:pp:pp:01".to_string(),
            "192.168.240.1".to_string(),
            "Apple, Inc.".to_string(),
            "Phone".to_string(),
            None,
        )
        .unwrap();

        let device = read("pp:pp:pp:pp:pp:01".to_string()).unwrap();
        assert_eq!(device.vendor, "Apple, Inc.".to_string());
        assert_eq!(device.device_type, "Laptop".to_string());
    }

    #[tokio::test]
    async fn test_update() {
        tests_common::setup().await;

        // update() overwrites owner, device_type and vendor unconditionally, leaving sighting
        // fields (ipv4_address, last_seen, name) and is_registered untouched.
        let last_seen = Utc::now();
        insert(Device {
            mac_address: "mm:mm:mm:mm:mm:01".to_string(),
            ipv4_address: "192.168.250.1".to_string(),
            vendor: "Old Vendor".to_string(),
            last_seen,
            is_registered: true,
            owner: "Alice".to_string(),
            device_type: "Phone".to_string(),
            name: Some("host.local".to_string()),
        })
        .unwrap();

        update(
            "mm:mm:mm:mm:mm:01".to_string(),
            "Bob".to_string(),
            "Laptop".to_string(),
            "New Vendor".to_string(),
        )
        .unwrap();

        let device = read("mm:mm:mm:mm:mm:01".to_string()).unwrap();
        assert_eq!(device.owner, "Bob".to_string());
        assert_eq!(device.device_type, "Laptop".to_string());
        assert_eq!(device.vendor, "New Vendor".to_string());
        // Sighting and registration fields are untouched
        assert_eq!(device.ipv4_address, "192.168.250.1".to_string());
        assert_eq!(device.last_seen, last_seen);
        assert_eq!(device.name, Some("host.local".to_string()));
        assert!(device.is_registered);
    }

    #[tokio::test]
    async fn test_register() {
        tests_common::setup().await;

        // A device with no deduced vendor must still persist the device_type chosen at registration.
        let last_seen = Utc::now();
        insert(Device::new(
            "rr:rr:rr:rr:rr:01".to_string(),
            "192.168.230.1".to_string(),
            "".to_string(),
            last_seen,
        ))
        .unwrap();

        register(
            "rr:rr:rr:rr:rr:01".to_string(),
            "Grace".to_string(),
            "Phone".to_string(),
            None,
        )
        .unwrap();

        let device = read("rr:rr:rr:rr:rr:01".to_string()).unwrap();
        assert!(device.is_registered, "Device should be registered");
        assert_eq!(device.owner, "Grace".to_string());
        assert_eq!(device.device_type, "Phone".to_string());
        assert_eq!(device.vendor, "".to_string());

        // Registering with Some(name) persists the supplied hostname.
        insert(Device::new(
            "rr:rr:rr:rr:rr:nm".to_string(),
            "192.168.230.5".to_string(),
            "".to_string(),
            Utc::now(),
        ))
        .unwrap();
        register(
            "rr:rr:rr:rr:rr:nm".to_string(),
            "Henry".to_string(),
            "Laptop".to_string(),
            Some("kitchen-laptop".to_string()),
        )
        .unwrap();
        let device = read("rr:rr:rr:rr:rr:nm".to_string()).unwrap();
        assert_eq!(device.name, Some("kitchen-laptop".to_string()));

        // Re-registering with None must NOT clobber the previously stored name.
        register(
            "rr:rr:rr:rr:rr:nm".to_string(),
            "Henry".to_string(),
            "Laptop".to_string(),
            None,
        )
        .unwrap();
        let device = read("rr:rr:rr:rr:rr:nm".to_string()).unwrap();
        assert_eq!(device.name, Some("kitchen-laptop".to_string()));
    }

    #[tokio::test]
    async fn test_unregister() {
        tests_common::setup().await;

        let last_seen = Utc::now();
        insert(Device::new(
            "rr:rr:rr:rr:rr:02".to_string(),
            "192.168.230.2".to_string(),
            "Test vendor".to_string(),
            last_seen,
        ))
        .unwrap();

        register(
            "rr:rr:rr:rr:rr:02".to_string(),
            "Grace".to_string(),
            "Phone".to_string(),
            None,
        )
        .unwrap();

        unregister("rr:rr:rr:rr:rr:02".to_string()).unwrap();

        let device = read("rr:rr:rr:rr:rr:02".to_string()).unwrap();
        assert!(!device.is_registered, "Device should not be registered");
        assert_eq!(device.owner, "".to_string());
        // device_type is left untouched by unregister
        assert_eq!(device.device_type, "Phone".to_string());
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
            &device,
            &Device {
                mac_address: "tt:tt:tt:tt:tt:aa".to_string(),
                device_type: "".to_string(),
                ipv4_address: "192.168.100.1".to_string(),
                is_registered: false,
                last_seen,
                owner: "".to_string(),
                vendor: "Test vendor".to_string(),
                name: None,
            },
        );

        // Insert complete device and validate it
        let last_seen = Utc::now();
        insert(Device {
            mac_address: "tt:tt:tt:tt:tt:bb".to_string(),
            device_type: "Server".to_string(),
            ipv4_address: "192.168.100.2".to_string(),
            is_registered: true,
            last_seen,
            owner: "Carl".to_string(),
            vendor: "Vendor X".to_string(),
            name: None,
        })
        .unwrap();

        let device = read("tt:tt:tt:tt:tt:bb".to_string()).unwrap();

        validate_device(
            &device,
            &Device {
                mac_address: "tt:tt:tt:tt:tt:bb".to_string(),
                device_type: "Server".to_string(),
                ipv4_address: "192.168.100.2".to_string(),
                is_registered: true,
                last_seen,
                owner: "Carl".to_string(),
                vendor: "Vendor X".to_string(),
                name: None,
            },
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
            &device1,
            &Device {
                mac_address: "aa:aa:aa:aa:aa:aa".to_string(),
                device_type: "".to_string(),
                ipv4_address: "192.168.0.1".to_string(),
                is_registered: false,
                last_seen: Utc.with_ymd_and_hms(2026, 1, 1, 11, 11, 11).unwrap(),
                owner: "".to_string(),
                vendor: "Vendor 1".to_string(),
                name: None,
            },
        );

        // 'bb:bb:bb:bb:bb:bb', '192.168.0.2', 'Vendor 2', '2026-02-03 13:14:15', 1, 'John', 'Phone'
        let device2 = read("bb:bb:bb:bb:bb:bb".to_string()).unwrap();
        validate_device(
            &device2,
            &Device {
                mac_address: "bb:bb:bb:bb:bb:bb".to_string(),
                device_type: "Phone".to_string(),
                ipv4_address: "192.168.0.2".to_string(),
                is_registered: true,
                last_seen: Utc.with_ymd_and_hms(2026, 2, 3, 13, 14, 15).unwrap(),
                owner: "John".to_string(),
                vendor: "Vendor 2".to_string(),
                name: None,
            },
        );

        // 'cc:cc:cc:cc:cc:cc', '192.168.0.3', 'Vendor 3', '2026-02-17 20:11:00', 1, 'Sarah', 'Laptop'
        let device3 = read("cc:cc:cc:cc:cc:cc".to_string()).unwrap();
        validate_device(
            &device3,
            &Device {
                mac_address: "cc:cc:cc:cc:cc:cc".to_string(),
                device_type: "Laptop".to_string(),
                ipv4_address: "192.168.0.3".to_string(),
                is_registered: true,
                last_seen: Utc.with_ymd_and_hms(2026, 2, 17, 20, 11, 00).unwrap(),
                owner: "Sarah".to_string(),
                vendor: "Vendor 3".to_string(),
                name: None,
            },
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

    fn validate_device(device: &Device, expected: &Device) {
        assert_eq!(
            device.mac_address, expected.mac_address,
            "Invalid MAC address for device {}",
            device.mac_address
        );
        assert_eq!(
            device.device_type, expected.device_type,
            "Invalid device type for device {}",
            device.mac_address
        );
        assert_eq!(
            device.ipv4_address, expected.ipv4_address,
            "Invalid IP address for device {}",
            device.mac_address
        );
        assert_eq!(
            device.is_registered, expected.is_registered,
            "Invalid registration status for device {}",
            device.mac_address
        );
        assert_eq!(
            device.last_seen, expected.last_seen,
            "Invalid last_seen for device {}",
            device.mac_address
        );
        assert_eq!(
            device.owner, expected.owner,
            "Invalid owner for device {}",
            device.mac_address
        );
        assert_eq!(
            device.vendor, expected.vendor,
            "Invalid vendor for device {}",
            device.mac_address
        );
        assert_eq!(
            device.name, expected.name,
            "Invalid name for device {}",
            device.mac_address
        );
    }
}
