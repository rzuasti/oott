use crate::settings::CONFIG;
use axum::{Router, routing::get};
use log::{LevelFilter, debug, info};
use std::sync::{Arc, Mutex};
use tokio::time::{Duration, sleep};
use tower_http::services::ServeDir;

mod db;
mod device_finders;
mod events;
mod mac_vendor_finder;
mod settings;

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

    tokio::join!(scanner(), web_server()).0
}

async fn web_server() -> Result<(), String> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route("/", get(|| async { "hello" }))
        .nest_service("/web", static_files);
    info!("Server running at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, router).await.unwrap();
    Ok(())
}

async fn scanner() -> Result<(), String> {
    // Get database connection - thread protected
    let db_conn = Arc::new(Mutex::new(db::init_db().unwrap()));

    loop {
        // Find online devices via ARP
        let devices = device_finders::arp::find(CONFIG.networking.interface.to_string()).await?;

        info!("Done with ARP probes");
        info!("Found {} online devices", devices.iter().count());

        // Process found devices
        for device in devices.iter() {
            debug!("Online device found {}", device);

            // Using just one connection for now, need to update if moved DB portion to multi-thread
            // need to change to a clone if we need multiple threads
            let db_conn_clone = Arc::clone(&db_conn);

            // Read device from database
            let recorded_device_result =
                db::devices::read(db_conn_clone.lock().unwrap(), device.mac_address.clone());

            match recorded_device_result {
                Some(recorded_device) => {
                    // If it exists update its last seen date
                    debug!(
                        "Device found in database {}. Updating to {}.",
                        recorded_device, device
                    );
                    db::devices::update(db_conn_clone.lock().unwrap(), device.clone())?;
                    events::trigger_existing_device(recorded_device, device.clone()).ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
                None => {
                    // If it doesn't exist insert it
                    debug!(
                        "Device with MAC address {} not found in database. Inserting it.",
                        device.mac_address
                    );

                    db::devices::insert(db_conn_clone.lock().unwrap(), device.clone())?;
                    events::trigger_new_device(device.clone()).ok(); // Ignoring errors here, do not stop loop if notification delivery fails
                }
            };
        }
        info!(
            "Scan finished. Sleeping for {} seconds",
            CONFIG.timings.wait_between_scans
        );
        sleep(Duration::from(CONFIG.timings.wait_between_scans)).await;
    }
}
