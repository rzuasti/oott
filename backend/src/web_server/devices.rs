use std::collections::HashMap;

use axum::extract::Path;
use axum::response::IntoResponse;
use axum::{Json, extract::Query, http::StatusCode};
use chrono::{DateTime, Utc};
use log::{debug, error};
use serde::Deserialize;

use crate::{db, model::devices::Device};

use crate::web_server::utils;

pub async fn list(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Device>>, StatusCode> {
    let is_registered: Option<bool> = utils::parse_parameter_bool(&params, "is_registered");
    let last_seen_from: Option<DateTime<Utc>> =
        utils::parse_parameter_date(&params, "last_seen_from");
    let last_seen_to: Option<DateTime<Utc>> = utils::parse_parameter_date(&params, "last_seen_to");
    let owner: Option<String> = utils::parse_parameter_string(&params, "owner");
    let device_type: Option<String> = utils::parse_parameter_string(&params, "device_type");
    let vendor: Option<String> = utils::parse_parameter_string(&params, "vendor");

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

pub async fn read(Path(mac_address): Path<String>) -> Result<Json<Device>, StatusCode> {
    match db::devices::read(mac_address) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn register(Json(payload): Json<RegisterDevicePayload>) -> impl IntoResponse {
    debug!(
        "Device registration received: mac_address={}, owner={}, device_type={}",
        payload.mac_address, payload.owner, payload.device_type
    );

    let mut device = match db::devices::read(payload.mac_address) {
        Some(value) => value,
        None => {
            return (
                axum::http::StatusCode::NOT_FOUND,
                "Device not found or could not be read",
            );
        }
    };

    if device.is_registered {
        return (
            axum::http::StatusCode::CONFLICT,
            "Device already registered",
        );
    }

    device.is_registered = true;
    device.owner = payload.owner;
    device.device_type = payload.device_type;

    match db::devices::update(device) {
        Ok(_) => (axum::http::StatusCode::CREATED, "Device registered"),
        Err(err) => {
            error!("Error registering device in the database: {}", err);
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Error registering device in the server, check your logs",
            )
        }
    }
}

pub async fn unregister(Path(mac_address): Path<String>) -> impl IntoResponse {
    let mut device = match db::devices::read(mac_address) {
        Some(value) => value,
        None => {
            return (
                axum::http::StatusCode::NOT_FOUND,
                "Device not found or could not be read",
            );
        }
    };

    if !device.is_registered {
        return (
            axum::http::StatusCode::CONFLICT,
            "Device not registered, you cannot un-register it again",
        );
    }

    device.is_registered = false;
    device.owner = "".to_string();
    device.device_type = "".to_string();

    match db::devices::update(device) {
        Ok(_) => (axum::http::StatusCode::OK, "Device un-registered"),
        Err(err) => {
            error!("Error updating device in the database: {}", err);
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Error updating device in the server, check your logs",
            )
        }
    }
}

// Payload structs
#[derive(Deserialize)]
pub struct RegisterDevicePayload {
    mac_address: String,
    owner: String,
    device_type: String,
}
