use crate::db;
use crate::db::error::DbError;
use chrono::{DateTime, Utc};
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::model::device_events::DeviceEvent;

pub fn insert(event: DeviceEvent) -> Result<i64, DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
        "INSERT INTO device_events (mac_address, created_on, event_type, ipv4_address, vendor) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![
            event.mac_address,
            event.created_on,
            event.event_type,
            event.ipv4_address,
            event.vendor
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

pub fn list(
    mac_address: Option<String>,
    page_offset: Option<i64>,
    page_limit: Option<i64>,
) -> Result<Vec<DeviceEvent>, DbError> {
    debug!("Listing device events");
    let conn = db::get_db_connection();

    let mut sql_statement =
        "SELECT id, mac_address, created_on, event_type, ipv4_address, vendor FROM device_events WHERE 1=1"
            .to_string();

    let mut params: Vec<rusqlite::types::Value> = Vec::new();

    if let Some(mac) = mac_address {
        debug!("Adding filter mac_address={}", mac);
        sql_statement.push_str(" AND mac_address=?");
        params.push(mac.into());
    }

    sql_statement.push_str(" ORDER BY created_on DESC, id DESC");

    if let (Some(page_offset), Some(page_limit)) = (page_offset, page_limit) {
        debug!(
            "Adding paging with offset={} and limit={}",
            page_offset, page_limit
        );
        sql_statement.push_str(" LIMIT ? OFFSET ?");
        params.push(page_limit.into());
        params.push(page_offset.into());
    }

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
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(events)
}

pub fn purge_older_than(cutoff: DateTime<Utc>) -> Result<usize, DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
        "DELETE FROM device_events WHERE created_on < ?1",
        params![cutoff],
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
    let conn = db::get_db_connection();

    let result: Result<DeviceEvent, rusqlite::Error> = conn.query_one(
        "SELECT id, mac_address, created_on, event_type, ipv4_address, vendor FROM device_events WHERE id=?1",
        params![id],
        |row| {
            Ok(DeviceEvent {
                id: row.get(0)?,
                mac_address: row.get(1)?,
                created_on: row.get(2)?,
                event_type: row.get(3)?,
                ipv4_address: row.get(4)?,
                vendor: row.get(5)?,
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
    use crate::{model::device_events::DeviceEventType, tests_common};

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
        ))
        .unwrap();

        assert!(inserted_id >= 0, "Inserted device event id should be positive");

        let event = read(inserted_id).unwrap();
        assert_eq!(event.mac_address, "aa:aa:aa:aa:aa:aa");
        assert_eq!(event.created_on, created_on);
        assert_eq!(event.event_type, DeviceEventType::NewDevice);
        assert_eq!(event.ipv4_address, "192.168.0.1");
        assert_eq!(event.vendor, "Vendor 1");

        let inserted_id = insert(DeviceEvent::new(
            "bb:bb:bb:bb:bb:bb".to_string(),
            Utc::now(),
            DeviceEventType::DeviceSeen,
            "192.168.0.2".to_string(),
            "Vendor 2".to_string(),
        ))
        .unwrap();

        let event = read(inserted_id).unwrap();
        assert_eq!(event.event_type, DeviceEventType::DeviceSeen);
    }

    #[tokio::test]
    async fn test_list() {
        tests_common::setup().await;

        let events = list(None, None, None).unwrap();
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

        let events = list(Some("aa:aa:aa:aa:aa:aa".to_string()), None, None).unwrap();
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

        let events = list(Some("zz:zz:zz:zz:zz:zz".to_string()), None, None).unwrap();
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
        ))
        .unwrap();

        let recent_id = insert(DeviceEvent::new(
            mac.clone(),
            Utc::now(),
            DeviceEventType::DeviceSeen,
            "10.0.0.200".to_string(),
            "Old Vendor".to_string(),
        ))
        .unwrap();

        let cutoff = Utc::now() - chrono::TimeDelta::days(365);
        let purged = purge_older_than(cutoff).unwrap();

        assert!(purged >= 1, "At least 1 device event should have been purged");
        assert!(read(old_id).is_none(), "Old device event should have been purged");
        assert!(read(recent_id).is_some(), "Recent device event should not have been purged");
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
        ))
        .unwrap();

        let first_page = list(Some(mac.clone()), Some(0), Some(2)).unwrap();
        assert_eq!(first_page.len(), 2, "First page should have 2 events");

        let second_page = list(Some(mac.clone()), Some(2), Some(2)).unwrap();
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
}
