use std::{collections::HashMap, error::Error};

use axum::{
    Json, Router,
    extract::{Path, Query},
    http::StatusCode,
    routing::get,
};
use chrono::{DateTime, Utc};
use log::{debug, error, info, warn};
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
        .route("/api/devices", get(list_devices))
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

fn parse_parameter_bool(params: &HashMap<String, String>, name: &str) -> Option<bool> {
    if params.contains_key(name) {
        let param_value = params.get(name).unwrap().as_str();
        debug!("Found parameter {name} with value {}", param_value);
        match param_value.parse::<bool>() {
            Ok(value) => Some(value),
            Err(_) => None,
        }
    } else {
        None
    }
}

fn parse_parameter_string(params: &HashMap<String, String>, name: &str) -> Option<String> {
    if params.contains_key(name) {
        let param_value = params.get(name).unwrap().as_str();
        debug!("Found parameter {name} with value {}", param_value);
        Some(param_value.to_string())
    } else {
        None
    }
}

fn parse_parameter_date(params: &HashMap<String, String>, name: &str) -> Option<DateTime<Utc>> {
    if params.contains_key(name) {
        let mut param_value = params.get(name).unwrap().to_ascii_uppercase();
        if !param_value.ends_with("Z") {
            param_value.push('Z');
        }
        debug!("Found parameter {name} with value {}", param_value);
        match DateTime::parse_from_rfc3339(param_value.as_str()) {
            Ok(value) => {
                debug!("Date parsed to {}", value.to_utc().to_rfc3339());
                Some(value.to_utc())
            }
            Err(err) => {
                warn!("Error parsing date from parameters: {}", err);
                None
            }
        }
    } else {
        None
    }
}

async fn list_devices(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Device>>, StatusCode> {
    let is_registered: Option<bool> = parse_parameter_bool(&params, "is_registered");
    let last_seen_from: Option<DateTime<Utc>> = parse_parameter_date(&params, "last_seen_from");
    let last_seen_to: Option<DateTime<Utc>> = parse_parameter_date(&params, "last_seen_to");
    let owner: Option<String> = parse_parameter_string(&params, "owner");
    let device_type: Option<String> = parse_parameter_string(&params, "device_type");
    let vendor: Option<String> = parse_parameter_string(&params, "vendor");

    match db::devices::list_devices(
        is_registered,
        last_seen_from,
        last_seen_to,
        owner,
        device_type,
        vendor,
    ) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing devices: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
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
