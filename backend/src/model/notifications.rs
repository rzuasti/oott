use crate::utils::date_serializer;
use chrono::{DateTime, Utc};
use rusqlite::types::{FromSql, FromSqlError, FromSqlResult, ToSql, ToSqlOutput, ValueRef};
use serde::{Deserialize, Serialize};
use std::{error::Error, fmt, str::FromStr};

#[derive(Clone, Serialize, Deserialize)]
pub struct Notification {
    pub id: i64,
    #[serde(with = "date_serializer")]
    pub created_on: DateTime<Utc>,
    pub notification_type: NotificationType,
    pub title: String,
    pub body: String,
    pub is_new: bool,
}

impl Notification {
    pub fn new(
        created_on: DateTime<Utc>,
        notification_type: NotificationType,
        title: String,
        body: String,
        is_new: bool,
    ) -> Self {
        Self {
            id: -1,
            created_on: created_on,
            notification_type: notification_type,
            title: title,
            body: body,
            is_new: is_new,
        }
    }
}

impl fmt::Display for Notification {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "id={}, created_on={}, notification_type={}, is_new={}\ntitle={}\nbody={}",
            self.id, self.created_on, self.notification_type, self.is_new, self.title, self.body
        )
    }
}

impl PartialEq for Notification {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum NotificationType {
    NewDeviceFound,
    DeviceOnlineAfterTime,
    DeviceChanged,
    Other,
}

impl fmt::Display for NotificationType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::NewDeviceFound => write!(f, "NewDeviceFound"),
            Self::DeviceOnlineAfterTime => write!(f, "DeviceOnlineAfterTime"),
            Self::DeviceChanged => write!(f, "DeviceChanged"),
            Self::Other => write!(f, "Other"),
        }
    }
}

#[derive(Debug)]
pub struct NotificationTypeParseError;

impl fmt::Display for NotificationTypeParseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error parsing notification type")
    }
}

impl Error for NotificationTypeParseError {}

impl FromStr for NotificationType {
    type Err = NotificationTypeParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "NewDeviceFound" => Ok(NotificationType::NewDeviceFound),
            "DeviceOnlineAfterTime" => Ok(NotificationType::DeviceOnlineAfterTime),
            _ => Ok(NotificationType::Other),
        }
    }
}

impl ToSql for NotificationType {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(self.to_string().into())
    }
}

impl FromSql for NotificationType {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        value
            .as_str()?
            .parse()
            .map_err(|e| FromSqlError::Other(Box::new(e)))
    }
}
