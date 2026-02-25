use chrono::{DateTime, Utc};
use serde::{Deserialize, Deserializer, Serialize, Serializer, de::Error};

fn time_to_json(t: DateTime<Utc>) -> String {
    t.to_rfc3339()
}

pub fn serialize<S: Serializer>(
    datetime: &DateTime<Utc>,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    time_to_json(datetime.clone()).serialize(serializer)
}

pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<DateTime<Utc>, D::Error> {
    let datetime: String = Deserialize::deserialize(deserializer)?;
    Ok(DateTime::parse_from_str(&datetime, "%Y-%m-%d %H:%M:%S")
        .map_err(D::Error::custom)?
        .to_utc())
}
