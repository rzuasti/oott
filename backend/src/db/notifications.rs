use crate::db;
use crate::db::error::DbError;
use log::{debug, error};
use rusqlite::{params, params_from_iter};

use crate::model::notifications::Notification;

pub fn list(
    is_new: Option<bool>,
    page_offset: Option<i64>,
    page_limit: Option<i64>,
) -> Result<Vec<Notification>, DbError> {
    debug!("Listing notifications");
    let conn = db::get_db_connection();

    let mut sql_statement =
        "SELECT id, created_on, notification_type, title, body, is_new FROM notifications WHERE 1=1"
            .to_string();

    let mut params: Vec<rusqlite::types::Value> = Vec::new();

    // Filters
    if is_new.is_some() {
        debug!("Adding filter is_new={}", is_new.unwrap());
        sql_statement.push_str(" AND is_new=?");

        params.push(is_new.unwrap().into());
    }

    // List order
    sql_statement.push_str(" ORDER BY created_on DESC");

    // Paging
    if page_offset.is_some() && page_limit.is_some() {
        debug!(
            "Adding paging to list with offset={} and limit={}",
            page_offset.unwrap(),
            page_limit.unwrap()
        );
        sql_statement.push_str(" LIMIT ? OFFSET ?");

        params.push(page_limit.unwrap().into());
        params.push(page_offset.unwrap().into());
    };

    let mut stmt = conn.prepare(sql_statement.as_str())?;

    let notifications: Vec<Notification> = stmt
        .query_map(params_from_iter(params.iter()), |row| {
            Ok(Notification {
                id: row.get(0)?,
                created_on: row.get(1)?,
                notification_type: row.get(2)?,
                title: row.get(3)?,
                body: row.get(4)?,
                is_new: row.get(5)?,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(notifications)
}

pub fn insert(notification: Notification) -> Result<i64, DbError> {
    let conn = db::get_db_connection();

    match conn.execute(
            "INSERT INTO notifications (created_on, notification_type, title, body, is_new) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![notification.created_on, notification.notification_type, notification.title, notification.body, notification.is_new]) {
                Ok(_) => {
                    debug!("Notification inserted into database: {}", notification);
                    Ok(conn.last_insert_rowid())
                },
                Err(error) => {
                    error!("Error inserting notification ({notification}) into database: {error}");
                    Err(DbError::from(error))
                },
        }
}

pub fn mark_as_old(id: i64) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    match conn.execute("UPDATE notifications SET is_new=0 WHERE id=?1", params![id]) {
        Ok(_) => {
            debug!("Notification id={} flagged as old", id);
            Ok(())
        }
        Err(error) => {
            error!("Error marking notification ({id}) as old: {error}");
            Err(DbError::from(error))
        }
    }
}

pub fn mark_as_new(id: i64) -> Result<(), DbError> {
    let conn = db::get_db_connection();

    match conn.execute("UPDATE notifications SET is_new=1 WHERE id=?1", params![id]) {
        Ok(_) => {
            debug!("Notification id={} flagged as new", id);
            Ok(())
        }
        Err(error) => {
            error!("Error marking notification ({id}) as new: {error}");
            Err(DbError::from(error))
        }
    }
}

pub fn read(id: i64) -> Option<Notification> {
    let conn = db::get_db_connection();

    let result: Result<Notification, rusqlite::Error> = conn.query_one(
        "SELECT id, created_on, notification_type, title, body, is_new FROM notifications WHERE id=?1",
        params![id],
        |row| {
            Ok(Notification {
                id: row.get(0)?,
                created_on: row.get(1)?,
                notification_type: row.get(2)?,
                title: row.get(3)?,
                body: row.get(4)?,
                is_new: row.get(5)?,
            })
        },
    );

    match result {
        Ok(value) => Some(value),
        Err(error) => {
            match error {
                rusqlite::Error::QueryReturnedNoRows => {
                    debug!("No notification found for id={id}.")
                }
                _ => error!("Error reading notification from database: {error}"),
            };
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};

    use super::*;
    use crate::{model::notifications::NotificationType, tests_common};

    #[tokio::test]
    async fn test_mark_as_old() {
        tests_common::setup().await;

        // Mark non-existant notification (should be fine)
        mark_as_old(9999999).unwrap();

        // Create new notification
        let created_on = Utc::now();
        let inserted_id = insert(Notification::new(
            created_on,
            NotificationType::DeviceOnlineAfterTime,
            "New notification title".to_string(),
            "New notification body".to_string(),
            true,
        ))
        .unwrap();

        // Mark it as old
        mark_as_old(inserted_id).unwrap();

        // Read it and validate
        let notification = read(inserted_id).unwrap();

        assert!(
            !notification.is_new,
            "Notification id={inserted_id} should have is_new=0."
        );
    }

    #[tokio::test]
    async fn test_mark_as_new() {
        tests_common::setup().await;

        // Mark non-existant notification (should be fine)
        mark_as_new(9999999).unwrap();

        // Create notification with is_new=false
        let created_on = Utc::now();
        let inserted_id = insert(Notification::new(
            created_on,
            NotificationType::DeviceOnlineAfterTime,
            "New notification title".to_string(),
            "New notification body".to_string(),
            false,
        ))
        .unwrap();

        // Mark it as new
        mark_as_new(inserted_id).unwrap();

        // Read it and validate
        let notification = read(inserted_id).unwrap();

        assert!(
            notification.is_new,
            "Notification id={inserted_id} should have is_new=1."
        );
    }

    #[tokio::test]
    async fn test_insert() {
        tests_common::setup().await;

        // Insert notification and read with returned ID
        let created_on = Utc::now();
        let inserted_id = insert(Notification::new(
            created_on,
            NotificationType::DeviceOnlineAfterTime,
            "New notification title".to_string(),
            "New notification body".to_string(),
            true,
        ))
        .unwrap();

        assert!(
            inserted_id >= 0,
            "Inserted notification id should be positive"
        );

        // Validate all fields
        let inserted_notification = read(inserted_id).unwrap();
        assert_eq!(
            inserted_notification.notification_type,
            NotificationType::DeviceOnlineAfterTime,
            "Wrong notification type (should be DeviceOnlineAfterTime)"
        );
        assert_eq!(
            inserted_notification.is_new, true,
            "Notification should be new"
        );
        assert_eq!(
            inserted_notification.created_on, created_on,
            "Wrong created_on (should be ${created_on})"
        );
        assert_eq!(
            inserted_notification.title, "New notification title",
            "Wrong title (should be 'New notification title')"
        );
        assert_eq!(
            inserted_notification.body, "New notification body",
            "Wrong body (should be 'New notification body')"
        );

        // Insert and validate notification without title nor body
        let created_on = Utc::now();
        let inserted_id = insert(Notification::new(
            created_on,
            NotificationType::Other,
            "".to_string(),
            "".to_string(),
            false,
        ))
        .unwrap();

        assert!(
            inserted_id >= 0,
            "Inserted notification id should be positive"
        );

        // Validate all fields
        let inserted_notification = read(inserted_id).unwrap();
        assert_eq!(
            inserted_notification.notification_type,
            NotificationType::Other,
            "Wrong notification type (should be Other)"
        );
        assert_eq!(
            inserted_notification.is_new, false,
            "Notification should not be new"
        );
        assert_eq!(
            inserted_notification.created_on, created_on,
            "Wrong created_on (should be ${created_on})"
        );
        assert_eq!(
            inserted_notification.title, "",
            "Wrong title (should be empty)"
        );
        assert_eq!(
            inserted_notification.body, "",
            "Wrong body (should be empty)"
        );
    }

    #[tokio::test]
    async fn test_read() {
        tests_common::setup().await;

        // Read existing notification
        let notification_option = read(2);

        // Notification should not be empty
        assert!(
            notification_option.is_some(),
            "Notification id=2 should be read"
        );

        // Validate all fields
        let notification = notification_option.unwrap();
        assert_eq!(notification.id, 2, "Wrong notification id (should be 2)");
        assert_eq!(
            notification.notification_type,
            NotificationType::NewDeviceFound,
            "Wrong notification type (should be NewDeviceFound)"
        );
        assert_eq!(notification.is_new, false, "Notification should not be new");
        assert_eq!(
            notification.created_on,
            Utc.with_ymd_and_hms(2026, 1, 4, 8, 10, 13).unwrap(),
            "Wrong created_on (should be 2026-01-04 08:10:13)"
        );
        assert_eq!(
            notification.title, "Read new device found",
            "Wrong title (should be 'Read new device found')"
        );
        assert_eq!(
            notification.body, "Body read new device found",
            "Wrong body (should be 'Body read new device found')"
        );

        // Read non-existant notification
        assert!(
            read(999999999).is_none(),
            "Notification id=999999999 should not exist"
        );

        // Insert notification and read with returned ID
        let created_on = Utc::now();
        let inserted_id = insert(Notification::new(
            created_on,
            NotificationType::DeviceOnlineAfterTime,
            "New notification title".to_string(),
            "New notification body".to_string(),
            true,
        ))
        .unwrap();

        // Validate all fields
        let inserted_notification = read(inserted_id).unwrap();
        assert_eq!(
            inserted_notification.notification_type,
            NotificationType::DeviceOnlineAfterTime,
            "Wrong notification type (should be DeviceOnlineAfterTime)"
        );
        assert_eq!(
            inserted_notification.is_new, true,
            "Notification should be new"
        );
        assert_eq!(
            inserted_notification.created_on, created_on,
            "Wrong created_on (should be ${created_on})"
        );
        assert_eq!(
            inserted_notification.title, "New notification title",
            "Wrong title (should be 'New notification title')"
        );
        assert_eq!(
            inserted_notification.body, "New notification body",
            "Wrong body (should be 'New notification body')"
        );

        // Read non-existant notification
        assert!(
            read(999999999).is_none(),
            "Notification id=999999999 should not exist"
        );
    }

    #[tokio::test]
    async fn test_list() {
        tests_common::setup().await;
        let notifications = list(Some(true), None, None).unwrap();

        // There should be at least 3 unread notifications
        assert!(
            notifications.len() >= 3,
            "There should be at least 3 notifications in the list"
        );

        // All notifications must be unread/new
        for notification in notifications.iter() {
            assert!(
                notification.is_new,
                "Notification {} is not new and there should only be new notifications in the list",
                notification.id
            );
        }

        // There should be at least one of each type
        assert!(
            notifications
                .iter()
                .filter(|notification| notification.notification_type == NotificationType::Other)
                .count()
                >= 1,
            "There should be at least one notification of type Other"
        );
        assert!(
            notifications
                .iter()
                .filter(|notification| notification.notification_type
                    == NotificationType::DeviceOnlineAfterTime)
                .count()
                >= 1,
            "There should be at least one notification of type DeviceOnlineAfterTime"
        );
        assert!(
            notifications
                .iter()
                .filter(|notification| notification.notification_type
                    == NotificationType::NewDeviceFound)
                .count()
                >= 1,
            "There should be at least one notification of type Other"
        );

        // Check date of notification 1
        let notification1 = notifications
            .iter()
            .filter(|notification| notification.id == 1)
            .next()
            .unwrap();

        // 2026-01-03 14:13:12 - UTC
        assert_eq!(
            notification1.created_on,
            Utc.with_ymd_and_hms(2026, 1, 3, 14, 13, 12).unwrap(),
            "Incorrect created_on date/time for notification 1."
        );

        // Check title of notification 3
        let notification3 = notifications
            .iter()
            .filter(|notification| notification.id == 3)
            .next()
            .unwrap();

        assert_eq!(
            notification3.title, "Unread device online after time",
            "Notification 3 title incorrect: {}",
            notification3.title
        );

        // Check body of notification 5
        let notification5 = notifications
            .iter()
            .filter(|notification| notification.id == 5)
            .next()
            .unwrap();

        assert_eq!(
            notification5.body, "Body other",
            "Notification 5 body incorrect: {}",
            notification5.body
        );
    }

    #[tokio::test]
    async fn test_list_filters() {
        tests_common::setup().await;

        // List only new notifications
        let notifications = list(Some(true), Some(0), Some(5)).unwrap();
        assert!(
            !notifications.iter().any(|item| !item.is_new),
            "All notifications should be new"
        );

        // List only old notifications
        let notifications = list(Some(false), Some(0), Some(5)).unwrap();
        assert!(
            !notifications.iter().any(|item| item.is_new),
            "All notifications should be old"
        );
    }

    #[tokio::test]
    async fn test_list_pagination() {
        tests_common::setup().await;

        // List first page with 2 elements
        let first_page = list(Some(true), Some(0), Some(2)).unwrap();

        assert_eq!(
            first_page.iter().len(),
            2,
            "First page should have 2 notifications"
        );

        // List second page with 2 elements, should only be 1
        let second_page = list(Some(true), Some(2), Some(2)).unwrap();
        assert!(
            second_page.iter().len() >= 1,
            "Second page should have at least 1 notification"
        );
    }
}
