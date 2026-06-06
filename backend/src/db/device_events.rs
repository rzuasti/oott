use crate::db;
use crate::db::error::DbError;
use chrono::{DateTime, Utc};
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::model::device_events::{DeviceEvent, DeviceEventScanner};
use crate::utils::network::normalize_mac;

pub fn insert(event: DeviceEvent) -> Result<i64, DbError> {
    let conn = db::get_db_connection()?;
    let mac_address = normalize_mac(&event.mac_address);

    match conn.execute(
        "INSERT INTO device_events (mac_address, created_on, event_type, ipv4_address, vendor, scanner) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![
            mac_address,
            event.created_on.to_rfc3339_opts(chrono::SecondsFormat::Nanos, false),
            event.event_type,
            event.ipv4_address,
            event.vendor,
            event.scanner
        ],
    ) {
        Ok(_) => {
            debug!("Device event inserted into database: {}", event);
            Ok(conn.last_insert_rowid())
        }
        Err(error) => {
            error!("Error inserting device event ({event}) into database: {error}");
            Err(DbError::from(error))
        }
    }
}

/// Returns true if an event with the same scanner, MAC and IPv4 address was already recorded
/// at or after `since`. Used to suppress duplicate sightings that the same scanner reports for
/// the same device within a short deduplication window.
pub fn recent_duplicate_exists(
    mac_address: &str,
    ipv4_address: &str,
    scanner: &DeviceEventScanner,
    since: DateTime<Utc>,
) -> Result<bool, DbError> {
    let conn = db::get_db_connection()?;
    let mac_address = normalize_mac(mac_address);

    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM device_events WHERE mac_address = ?1 AND ipv4_address = ?2 AND scanner = ?3 AND created_on >= ?4",
        params![
            mac_address,
            ipv4_address,
            scanner,
            since.to_rfc3339_opts(chrono::SecondsFormat::Nanos, false)
        ],
        |row| row.get(0),
    )?;

    Ok(count > 0)
}

pub fn list(
    mac_address: Option<String>,
    created_from: Option<DateTime<Utc>>,
    page_offset: Option<i64>,
    page_limit: Option<i64>,
) -> Result<Vec<DeviceEvent>, DbError> {
    debug!("Listing device events");
    let conn = db::get_db_connection()?;

    let mut sql_statement =
        "SELECT id, mac_address, created_on, event_type, ipv4_address, vendor, scanner FROM device_events WHERE 1=1"
            .to_string();

    let mut params: Vec<rusqlite::types::Value> = Vec::new();

    if let Some(mac) = mac_address {
        let mac = normalize_mac(&mac);
        debug!("Adding filter mac_address={}", mac);
        sql_statement.push_str(" AND mac_address=?");
        params.push(mac.into());
    }

    if let Some(from) = created_from {
        debug!("Adding filter created_on >= {}", from);
        sql_statement.push_str(" AND created_on >= ?");
        params.push(from.to_rfc3339().into());
    }

    sql_statement.push_str(" ORDER BY created_on DESC, id DESC");

    db::apply_paging(&mut sql_statement, &mut params, page_offset, page_limit);

    let mut stmt = conn.prepare(sql_statement.as_str())?;

    let events: Vec<DeviceEvent> = stmt
        .query_map(params_from_iter(params.iter()), |row| {
            Ok(DeviceEvent {
                id: row.get(0)?,
                mac_address: row.get(1)?,
                created_on: row.get(2)?,
                event_type: row.get(3)?,
                ipv4_address: row.get(4)?,
                vendor: row.get(5)?,
                scanner: row.get(6)?,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(events)
}

pub fn purge_older_than(cutoff: DateTime<Utc>) -> Result<usize, DbError> {
    let conn = db::get_db_connection()?;

    match conn.execute(
        "DELETE FROM device_events WHERE created_on < ?1",
        params![cutoff.to_rfc3339()],
    ) {
        Ok(count) => {
            debug!("Purged {} device event(s) older than {}", count, cutoff);
            Ok(count)
        }
        Err(error) => {
            error!("Error purging old device events: {error}");
            Err(DbError::from(error))
        }
    }
}

#[cfg(test)]
fn read(id: i64) -> Option<DeviceEvent> {
    let conn = match db::get_db_connection() {
        Ok(conn) => conn,
        Err(error) => {
            error!("Error obtaining database connection: {error}");
            return None;
        }
    };

    let result: Result<DeviceEvent, rusqlite::Error> = conn.query_one(
        "SELECT id, mac_address, created_on, event_type, ipv4_address, vendor, scanner FROM device_events WHERE id=?1",
        params![id],
        |row| {
            Ok(DeviceEvent {
                id: row.get(0)?,
                mac_address: row.get(1)?,
                created_on: row.get(2)?,
                event_type: row.get(3)?,
                ipv4_address: row.get(4)?,
                vendor: row.get(5)?,
                scanner: row.get(6)?,
            })
        },
    );

    match result {
        Ok(value) => Some(value),
        Err(error) => {
            match error {
                rusqlite::Error::QueryReturnedNoRows => {
                    debug!("No device event found for id={id}.")
                }
                _ => error!("Error reading device event from database: {error}"),
            };
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use chrono::Utc;

    use super::*;
    use crate::{
        model::device_events::{DeviceEventScanner, DeviceEventType},
        tests_common,
    };

    #[tokio::test]
    async fn test_insert() {
        tests_common::setup().await;

        let created_on = Utc::now();
        let inserted_id = insert(DeviceEvent::new(
            "aa:aa:aa:aa:aa:aa".to_string(),
            created_on,
            DeviceEventType::NewDevice,
            "192.168.0.1".to_string(),
            "Vendor 1".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        assert!(
            inserted_id >= 0,
            "Inserted device event id should be positive"
        );

        let event = read(inserted_id).unwrap();
        assert_eq!(event.mac_address, "aa:aa:aa:aa:aa:aa");
        assert_eq!(event.created_on, created_on);
        assert_eq!(event.event_type, DeviceEventType::NewDevice);
        assert_eq!(event.ipv4_address, "192.168.0.1");
        assert_eq!(event.vendor, "Vendor 1");
        assert_eq!(event.scanner, DeviceEventScanner::Arp);

        let inserted_id = insert(DeviceEvent::new(
            "bb:bb:bb:bb:bb:bb".to_string(),
            Utc::now(),
            DeviceEventType::DeviceSeen,
            "192.168.0.2".to_string(),
            "Vendor 2".to_string(),
            DeviceEventScanner::Mdns,
        ))
        .unwrap();

        let event = read(inserted_id).unwrap();
        assert_eq!(event.event_type, DeviceEventType::DeviceSeen);
        assert_eq!(event.scanner, DeviceEventScanner::Mdns);
    }

    #[tokio::test]
    async fn test_recent_duplicate_exists() {
        tests_common::setup().await;

        let mac = "ab:cd:ef:00:11:22".to_string();
        let ip = "192.168.5.5".to_string();
        let created_on = Utc::now();
        insert(DeviceEvent::new(
            mac.clone(),
            created_on,
            DeviceEventType::DeviceSeen,
            ip.clone(),
            "Vendor".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let within_window = created_on - chrono::TimeDelta::seconds(60);

        // Same scanner, MAC and IP within the window is a duplicate.
        assert!(
            recent_duplicate_exists(&mac, &ip, &DeviceEventScanner::Arp, within_window).unwrap()
        );

        // A different IP is not a duplicate.
        assert!(
            !recent_duplicate_exists(&mac, "192.168.5.6", &DeviceEventScanner::Arp, within_window)
                .unwrap()
        );

        // A different scanner is not a duplicate.
        assert!(
            !recent_duplicate_exists(&mac, &ip, &DeviceEventScanner::Mdns, within_window).unwrap()
        );

        // A cutoff after the stored event (outside the window) is not a duplicate.
        let after_event = created_on + chrono::TimeDelta::seconds(1);
        assert!(
            !recent_duplicate_exists(&mac, &ip, &DeviceEventScanner::Arp, after_event).unwrap()
        );
    }

    #[tokio::test]
    async fn test_list() {
        tests_common::setup().await;

        let events = list(None, None, None, None).unwrap();
        assert!(
            events.len() >= 3,
            "There should be at least 3 device events from seed data"
        );

        // Verify ordering: created_on DESC — first element should be newest
        if events.len() >= 2 {
            assert!(
                events[0].created_on >= events[1].created_on,
                "Events should be ordered by created_on DESC"
            );
        }

        let event3 = events.iter().find(|e| e.id == 3).unwrap();
        assert_eq!(event3.mac_address, "aa:aa:aa:aa:aa:aa");
        assert_eq!(event3.event_type, DeviceEventType::DeviceSeen);
    }

    #[tokio::test]
    async fn test_list_filter_by_mac_address() {
        tests_common::setup().await;

        let events = list(Some("aa:aa:aa:aa:aa:aa".to_string()), None, None, None).unwrap();
        assert!(
            events.len() >= 2,
            "There should be at least 2 events for aa:aa:aa:aa:aa:aa"
        );
        for event in &events {
            assert_eq!(
                event.mac_address, "aa:aa:aa:aa:aa:aa",
                "All returned events should belong to mac_address aa:aa:aa:aa:aa:aa"
            );
        }

        let events = list(Some("zz:zz:zz:zz:zz:zz".to_string()), None, None, None).unwrap();
        assert!(events.is_empty(), "Unknown MAC should return empty list");
    }

    #[tokio::test]
    async fn test_purge_older_than() {
        tests_common::setup().await;

        let mac = "ee:ee:ee:ee:ee:ee".to_string();
        let old_id = insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2020-01-01T00:00:00+00:00")
                .unwrap()
                .into(),
            DeviceEventType::NewDevice,
            "10.0.0.200".to_string(),
            "Old Vendor".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let recent_id = insert(DeviceEvent::new(
            mac.clone(),
            Utc::now(),
            DeviceEventType::DeviceSeen,
            "10.0.0.200".to_string(),
            "Old Vendor".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let cutoff = Utc::now() - chrono::TimeDelta::days(365);
        let purged = purge_older_than(cutoff).unwrap();

        assert!(
            purged >= 1,
            "At least 1 device event should have been purged"
        );
        assert!(
            read(old_id).is_none(),
            "Old device event should have been purged"
        );
        assert!(
            read(recent_id).is_some(),
            "Recent device event should not have been purged"
        );
    }

    #[tokio::test]
    async fn test_list_pagination() {
        tests_common::setup().await;

        let mac = "cc:cc:cc:cc:cc:cc".to_string();
        insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2026-01-01T00:00:00Z")
                .unwrap()
                .into(),
            DeviceEventType::NewDevice,
            "10.0.0.1".to_string(),
            "Vendor C".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();
        insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2026-02-01T00:00:00Z")
                .unwrap()
                .into(),
            DeviceEventType::DeviceSeen,
            "10.0.0.1".to_string(),
            "Vendor C".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();
        insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2026-03-01T00:00:00Z")
                .unwrap()
                .into(),
            DeviceEventType::DeviceSeen,
            "10.0.0.1".to_string(),
            "Vendor C".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let first_page = list(Some(mac.clone()), None, Some(0), Some(2)).unwrap();
        assert_eq!(first_page.len(), 2, "First page should have 2 events");

        let second_page = list(Some(mac.clone()), None, Some(2), Some(2)).unwrap();
        assert_eq!(second_page.len(), 1, "Second page should have 1 event");

        let first_ids: Vec<i64> = first_page.iter().map(|e| e.id).collect();
        for event in &second_page {
            assert!(
                !first_ids.contains(&event.id),
                "Event id={} should not appear in both pages",
                event.id
            );
        }
    }

    #[tokio::test]
    async fn test_list_created_from_none_returns_all() {
        tests_common::setup().await;

        let mac = "ff:ff:ff:ff:ff:ff".to_string();
        insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2024-01-01T00:00:00Z")
                .unwrap()
                .into(),
            DeviceEventType::NewDevice,
            "10.0.0.1".to_string(),
            "Vendor F".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();
        insert(DeviceEvent::new(
            mac.clone(),
            chrono::DateTime::parse_from_rfc3339("2026-01-01T00:00:00Z")
                .unwrap()
                .into(),
            DeviceEventType::DeviceSeen,
            "10.0.0.1".to_string(),
            "Vendor F".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let events = list(Some(mac.clone()), None, None, None).unwrap();
        assert_eq!(
            events.len(),
            2,
            "created_from=None should return all events without filtering"
        );
    }

    #[tokio::test]
    async fn test_list_created_from_filters_older_events() {
        tests_common::setup().await;

        let mac = "dd:dd:dd:dd:dd:dd".to_string();
        let old_ts: DateTime<Utc> = chrono::DateTime::parse_from_rfc3339("2024-01-01T00:00:00Z")
            .unwrap()
            .into();
        let new_ts: DateTime<Utc> = chrono::DateTime::parse_from_rfc3339("2026-01-01T00:00:00Z")
            .unwrap()
            .into();
        let cutoff: DateTime<Utc> = chrono::DateTime::parse_from_rfc3339("2025-06-01T00:00:00Z")
            .unwrap()
            .into();

        insert(DeviceEvent::new(
            mac.clone(),
            old_ts,
            DeviceEventType::NewDevice,
            "10.0.0.1".to_string(),
            "Vendor D".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();
        insert(DeviceEvent::new(
            mac.clone(),
            new_ts,
            DeviceEventType::DeviceSeen,
            "10.0.0.1".to_string(),
            "Vendor D".to_string(),
            DeviceEventScanner::Arp,
        ))
        .unwrap();

        let events = list(Some(mac.clone()), Some(cutoff), None, None).unwrap();
        assert_eq!(
            events.len(),
            1,
            "Only the event after the cutoff should be returned"
        );
        assert_eq!(events[0].created_on, new_ts);
    }
}
