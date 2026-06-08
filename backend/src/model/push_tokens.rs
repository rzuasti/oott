use crate::utils::date_serializer;
use chrono::{DateTime, Utc};
use rusqlite::types::{FromSql, FromSqlError, FromSqlResult, ToSql, ToSqlOutput, ValueRef};
use serde::{Deserialize, Serialize};
use std::{error::Error, fmt, str::FromStr};
use utoipa::ToSchema;

// A device push-notification token registered by an instance of the OOTT mobile app. Tokens are
// stored locally by the self-hosted backend; the project-operated relay never persists them.
#[derive(Clone, Serialize, Deserialize, ToSchema)]
pub struct PushToken {
    pub id: i64,
    pub token: String,
    pub platform: PushPlatform,
    #[serde(with = "date_serializer")]
    #[schema(value_type = String, format = DateTime)]
    pub created_on: DateTime<Utc>,
    #[serde(with = "date_serializer")]
    #[schema(value_type = String, format = DateTime)]
    pub last_seen: DateTime<Utc>,
}

impl fmt::Display for PushToken {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        // The token itself is a credential, so it is never logged in full; only a short suffix is
        // shown to make log lines correlatable without exposing the value.
        let suffix = if self.token.len() > 6 {
            &self.token[self.token.len() - 6..]
        } else {
            self.token.as_str()
        };
        write!(
            f,
            "id={}, platform={}, token=…{}, created_on={}, last_seen={}",
            self.id, self.platform, suffix, self.created_on, self.last_seen
        )
    }
}

// The OS push platform a token belongs to. Sent by the app at registration and stored so the relay
// payload can be tailored per platform if ever needed.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum PushPlatform {
    Android,
    Ios,
}

impl fmt::Display for PushPlatform {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::Android => write!(f, "android"),
            Self::Ios => write!(f, "ios"),
        }
    }
}

#[derive(Debug)]
pub struct PushPlatformParseError;

impl fmt::Display for PushPlatformParseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error parsing push platform")
    }
}

impl Error for PushPlatformParseError {}

impl FromStr for PushPlatform {
    type Err = PushPlatformParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "android" => Ok(PushPlatform::Android),
            "ios" => Ok(PushPlatform::Ios),
            _ => Err(PushPlatformParseError),
        }
    }
}

impl ToSql for PushPlatform {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(self.to_string().into())
    }
}

impl FromSql for PushPlatform {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        value
            .as_str()?
            .parse()
            .map_err(|e| FromSqlError::Other(Box::new(e)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn platform_display_and_parse_round_trip() {
        for platform in [PushPlatform::Android, PushPlatform::Ios] {
            let text = platform.to_string();
            assert_eq!(text.parse::<PushPlatform>().unwrap(), platform);
        }
    }

    #[test]
    fn platform_parse_is_case_insensitive() {
        assert_eq!("ANDROID".parse::<PushPlatform>().unwrap(), PushPlatform::Android);
        assert_eq!("iOS".parse::<PushPlatform>().unwrap(), PushPlatform::Ios);
    }

    #[test]
    fn platform_parse_rejects_unknown_values() {
        assert!("windows".parse::<PushPlatform>().is_err());
        assert!("".parse::<PushPlatform>().is_err());
    }
}
