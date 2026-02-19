use crate::db;
use crate::db::error::DbError;
use log::debug;

use crate::model::notifications::Notification;

pub fn list() -> Result<Vec<Notification>, DbError> {
    debug!("Listing notifications");
    let conn = db::get_db_connection();

    let mut stmt = conn.prepare(
        "SELECT id, created_on, notification_type, title, body FROM notifications WHERE is_new=1",
    )?;

    let notifications: Vec<Notification> = stmt
        .query_map([], |row| {
            Ok(Notification {
                id: row.get(0)?,
                created_on: row.get(1)?,
                notification_type: row.get(2)?,
                title: row.get(3)?,
                body: row.get(4)?,
                is_new: true,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(notifications)
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;

    use super::*;
    use crate::{model::notifications::NotificationType, tests_common};

    #[tokio::test]
    async fn test_list_default() {
        tests_common::setup().await;
        let notifications = list().unwrap();

        // There should be 3 unread notifications
        assert_eq!(
            notifications.len(),
            3,
            "There should be 3 notifications in the list"
        );

        // All notifications must be unread/new
        for notification in notifications.iter() {
            assert!(
                notification.is_new,
                "Notification {} is not new and there should only be new notifications in the list",
                notification.id
            );
        }

        // There should be only one of each type
        assert_eq!(
            1,
            notifications
                .iter()
                .filter(|notification| notification.notification_type == NotificationType::Other)
                .count(),
            "There should be only one notification of type Other"
        );
        assert_eq!(
            1,
            notifications
                .iter()
                .filter(|notification| notification.notification_type
                    == NotificationType::DeviceOnlineAfterTime)
                .count(),
            "There should be only one notification of type Other"
        );
        assert_eq!(
            1,
            notifications
                .iter()
                .filter(|notification| notification.notification_type
                    == NotificationType::NewDeviceFound)
                .count(),
            "There should be only one notification of type Other"
        );

        // Check date of notification 1
        let notification1 = notifications
            .iter()
            .filter(|notification| notification.id == 1)
            .next()
            .unwrap();

        // 2026-01-03 14:13:12
        assert_eq!(
            notification1.created_on,
            Local.with_ymd_and_hms(2026, 1, 3, 14, 13, 12).unwrap(),
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
}
