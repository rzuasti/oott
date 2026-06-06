use crate::settings::get_settings;
use clap::Parser;
use log::{LevelFilter, info};

mod data;
mod db;
mod events;
mod model;
mod retention;
mod scanners;
mod settings;
mod utils;
mod web_server;

#[cfg(test)]
mod tests_common;

// Command line parameters
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Config file path
    #[arg(short, long)]
    config: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Parse command line parameters and init settings
    // this is not thread safe so it needs to run just once
    let args = Args::parse();
    let config_path = args
        .config
        .unwrap_or(settings::DEFAULT_CONFIG_FILE_PATH.to_string());
    settings::init(config_path);

    // Initialize logging
    let log_level = match get_settings().log.level.as_str() {
        "off" => LevelFilter::Off,
        "error" => LevelFilter::Error,
        "warn" => LevelFilter::Warn,
        "info" => LevelFilter::Info,
        "debug" => LevelFilter::Debug,
        "trace" => LevelFilter::Trace,
        _ => LevelFilter::Error,
    };

    env_logger::Builder::new()
        .filter(None, log_level)
        .write_style(env_logger::WriteStyle::Always)
        .init();

    // Now onto the important stuff
    info!("Starting up oott");

    // Initialize database
    db::init_db().await?;

    // Initialize scanner status tracking
    scanners::arp::status::STATUS.init();
    scanners::mdns::status::STATUS.init();
    scanners::ssdp::status::STATUS.init();
    scanners::dhcp::status::STATUS.init();
    scanners::snmp::status::STATUS.init();

    // Start the device scanners, web server, retention cleaner, and notification delivery loop in
    // parallel. Notification delivery runs on its own task so a slow Pushover never stalls a scan.
    tokio::join!(
        scanners::arp::scanner::scan(),
        scanners::mdns::scanner::listen(),
        scanners::ssdp::scanner::listen(),
        scanners::dhcp::scanner::listen(),
        scanners::snmp::scanner::scan(),
        web_server::serve(),
        retention::run(),
        events::run_delivery()
    )
    .0
}
