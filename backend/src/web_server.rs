use std::error::Error;

use axum::Router;
use axum::routing::{delete, get, put};
use log::{debug, info};
use tower_http::services::ServeDir;

pub mod devices;
pub mod notifications;
pub mod utils;

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route(
            "/",
            get(|| async { "Go to /web for the UI or to /api for the better UI." }),
        )
        .route("/api/devices", get(devices::list))
        .route("/api/devices", put(devices::register))
        .route("/api/devices/{mac_address}", delete(devices::unregister))
        .route("/api/devices/{mac_address}", get(devices::read))
        .route("/api/notifications", get(notifications::list))
        .route("/api/notifications/{id}", get(notifications::read))
        .route(
            "/api/notifications/{id}/read_without_flagging",
            get(notifications::read_without_flagging),
        )
        .nest_service("/web", static_files);
    info!("Web server starting at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;

    debug!("Web server bound to IP and port");

    axum::serve(listener, router).await?;
    Ok(())
}
