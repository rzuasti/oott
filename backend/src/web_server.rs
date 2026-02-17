use axum::{Json, Router, http::StatusCode, routing::get};
use chrono::Local;
use log::info;
use tower_http::services::ServeDir;

use crate::model::devices::Device;

pub async fn serve() -> Result<(), String> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route("/", get(|| async { "hello" }))
        .route("/devices", get(get_devices))
        .nest_service("/web", static_files);
    info!("Server running at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, router).await.unwrap();
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
