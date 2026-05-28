use config::{Config, ConfigError, File};
use duration_string::DurationString;
use once_cell::sync::OnceCell;
use serde::Deserialize;

// -----------------------------------------------------------
// Configuration structure

#[derive(Debug, Deserialize, Clone)]
pub struct Database {
    pub path: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Networking {
    pub interface: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Log {
    pub level: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ArpScanner {
    pub wait_between_scans: DurationString,
    pub sender_timeout: DurationString,
    pub scan_duration: DurationString,
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
pub struct WebServer {
    pub ip_address: String,
    pub port: u16,
    pub api_key: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Retention {
    pub window: DurationString,
}

impl Default for Retention {
    fn default() -> Self {
        Retention {
            window: DurationString::try_from("365d".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub database: Database,
    pub networking: Networking,
    pub log: Log,
    pub arp_scanner: ArpScanner,
    pub notifications: Notifications,
    pub web_server: WebServer,
    #[serde(default)]
    pub retention: Retention,
}
// End configuration structure
// -----------------------------------------------------------

impl Settings {
    pub fn new(config_path: String) -> Result<Self, ConfigError> {
        println!("Reading configuration from {}", config_path);

        let local_settings = Config::builder()
            .add_source(File::with_name(config_path.as_str()))
            .build()?;

        local_settings.try_deserialize()
    }
}

pub const DEFAULT_CONFIG_FILE_PATH: &str = "./oott.toml";
static SETTINGS: OnceCell<Settings> = OnceCell::new();

pub fn get_settings() -> &'static Settings {
    match SETTINGS.get() {
        Some(value) => value,
        None => {
            println!(
                "Configuration was not initialized, reading from default path ({})",
                DEFAULT_CONFIG_FILE_PATH
            );
            let settings = Settings::new(DEFAULT_CONFIG_FILE_PATH.to_string()).unwrap();
            let _ = SETTINGS.set(settings);
            SETTINGS.get().unwrap()
        }
    }
}

pub fn init(config_path: String) {
    let _ = SETTINGS.set(Settings::new(config_path).unwrap());
}
