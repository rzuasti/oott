use std::error::Error;

use axum::{Json, Router, http::StatusCode, routing::get};
use chrono::Local;
use log::{debug, error, info};
use tower_http::services::ServeDir;

use crate::{
    db,
    model::{devices::Device, notifications::Notification},
};

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route("/", get(|| async { "hello" }))
        .route("/devices", get(get_devices))
        .route("/notifications", get(list_notifications))
        .nest_service("/web", static_files);
    info!("Web server starting at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;

    debug!("Web server bound to IP and port");

    axum::serve(listener, router).await?;
    Ok(())
}

async fn get_devices() -> Result<Json<Vec<Device>>, StatusCode> {
    let mut devices = Vec::new();

    devices.push(Device {
        mac_address: "mac".to_string(),
        ipv4_address: "ip".to_string(),
        vendor: "vendor".to_string(),
        last_seen: Local::now().to_utc(),
    });

    Ok(Json(devices))
}

async fn list_notifications() -> Result<Json<Vec<Notification>>, StatusCode> {
    match db::notifications::list() {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing notifications: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
