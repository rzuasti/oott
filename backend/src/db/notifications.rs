use chrono::Local;
use log::debug;

use crate::model::{self, notifications::Notification};

pub fn list() -> Vec<model::notifications::Notification> {
    debug!("Listing notifications");
    let mut result = Vec::new();
    result.push(Notification {
        id: 1,
        created_on: Local::now().to_utc(),
        is_new: true,
        notification_type: model::notifications::NotificationType::NewDeviceFound,
        title: "title".to_string(),
        body: "body".to_string(),
    });

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn list_default() {
        tests_common::setup().await;
        let notifications = list();
        assert_eq!(notifications.len(), 1);
    }
}
