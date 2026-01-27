use clap::Parser;
use config::{Config, ConfigError, File};
use duration_string::DurationString;
use lazy_static::lazy_static;
use log::{error, info};
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

// Command line parameters relevant to configuration
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Config file path
    #[arg(short, long)]
    config: Option<String>,
}

const DEFAULT_CONFIG_FILE_PATH: &str = "./oott.toml";

impl Settings {
    pub fn new() -> Result<Self, ConfigError> {
        let args = Args::parse();

        let config_path = args.config.unwrap_or(DEFAULT_CONFIG_FILE_PATH.to_string());

        info!("Reading configuration from {}", config_path);

        let local_settings = Config::builder()
            .add_source(File::with_name(config_path.as_str()))
            .build()?;

        local_settings.try_deserialize()
    }
}

lazy_static! {
    pub static ref CONFIG: Settings = match Settings::new() {
        Ok(value) => value,
        Err(error) => {
            error!("Error reading configuration file: {error}");
            panic!("Error reading configuration file: {error}");
        }
    };
}
