use std::error::Error;

use axum::{Router, routing::get};
use log::{debug, info};
use tower_http::services::ServeDir;

pub mod devices;
pub mod notifications;
pub mod utils;

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route("/", get(|| async { "hello" }))
        .route("/api/devices", get(devices::list_devices))
        .route("/api/notifications", get(notifications::list_notifications))
        .route(
            "/api/notifications/{id}",
            get(notifications::read_notification),
        )
        .route(
            "/api/notifications/{id}/read_without_flagging",
            get(notifications::read_notification_without_flagging),
        )
        .nest_service("/web", static_files);
    info!("Web server starting at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;

    debug!("Web server bound to IP and port");

    axum::serve(listener, router).await?;
    Ok(())
}
