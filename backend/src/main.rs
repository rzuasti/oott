use crate::settings::CONFIG;
use log::{LevelFilter, info};

mod db;
mod device_finders;
mod events;
mod mac_vendor_finder;
mod model;
mod scanner;
mod settings;
mod web_server;

#[tokio::main]
async fn main() -> Result<(), String> {
    // Initialize logging
    let log_level = match CONFIG.log.level.as_str() {
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

    // Start the device scanner and web server (for API and UI) in parallel
    tokio::join!(scanner::scan(), web_server::serve()).0
}
