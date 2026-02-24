use std::error::Error;

use axum::{Json, Router, extract::Path, http::StatusCode, routing::get};
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
        .route("/api/devices", get(get_devices))
        .route("/api/notifications", get(list_notifications))
        .route("/api/notifications/{id}", get(read_notification))
        .route(
            "/api/notifications/{id}/read_without_flagging",
            get(read_notification_without_flagging),
        )
        .nest_service("/web", static_files);
    info!("Web server starting at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;

    debug!("Web server bound to IP and port");

    axum::serve(listener, router).await?;
    Ok(())
}

async fn get_devices() -> Result<Json<Vec<Device>>, StatusCode> {
    unimplemented!();
}

async fn read_notification(Path(id): Path<i64>) -> Result<Json<Notification>, StatusCode> {
    match db::notifications::mark_as_old(id) {
        Ok(_) => {}
        Err(err) => {
            error!("Error marking notification (id={id}) as old: {}", err);
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    match db::notifications::read(id) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

async fn read_notification_without_flagging(
    Path(id): Path<i64>,
) -> Result<Json<Notification>, StatusCode> {
    match db::notifications::read(id) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
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
