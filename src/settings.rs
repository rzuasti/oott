use config::{Config, ConfigError, File};
use duration_string::DurationString;
use lazy_static::lazy_static;
use log::error;
use serde::Deserialize;

// -----------------------------------------------------------
// Configuration structure

#[derive(Debug, Deserialize, Clone)]
pub struct Networking {
    pub interface: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Log {
    pub level: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Timings {
    pub wait_between_scans: DurationString,
    pub arp_sender_timeout: DurationString,
    pub arp_scan_duration: DurationString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Pushover {
    pub token: String,
    pub user_key: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Notifications {
    pub method: String,
    pub pushover: Pushover,
    pub notify_when_not_seen_for: DurationString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub networking: Networking,
    pub log: Log,
    pub timings: Timings,
    pub notifications: Notifications,
}
// End configuration structure
// -----------------------------------------------------------

const CONFIG_FILE_PATH: &str = "./oott.toml";

impl Settings {
    pub fn new() -> Result<Self, ConfigError> {
        let local_settings = Config::builder()
            .add_source(File::with_name(CONFIG_FILE_PATH))
            .build()?;

        local_settings.try_deserialize()
    }
}

lazy_static! {
    pub static ref CONFIG: Settings = match Settings::new() {
        Ok(value) => value,
        Err(error) => {
            error!("Error reading configuration file ({CONFIG_FILE_PATH}): {error}");
            panic!("Error reading configuration file ({CONFIG_FILE_PATH}): {error}");
        }
    };
}
