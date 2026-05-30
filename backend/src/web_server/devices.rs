use std::collections::HashMap;

use axum::extract::Path;
use axum::response::IntoResponse;
use axum::{Json, extract::Query, http::StatusCode};
use chrono::{DateTime, Utc};
use log::{debug, error};
use serde::Deserialize;
use utoipa::ToSchema;

use crate::{
    db,
    model::devices::{Device, DeviceSummary},
};

use crate::web_server::utils;

#[utoipa::path(
    get,
    path = "/api/devices",
    tag = "devices",
    params(
        ("is_registered" = Option<bool>, Query, description = "Filter by registration status"),
        ("last_seen_from" = Option<String>, Query, description = "Filter devices seen after this datetime (RFC3339)"),
        ("last_seen_to" = Option<String>, Query, description = "Filter devices seen before this datetime (RFC3339)"),
        ("owner" = Option<String>, Query, description = "Filter by owner"),
        ("device_type" = Option<String>, Query, description = "Filter by device type"),
        ("vendor" = Option<String>, Query, description = "Filter by vendor"),
        ("page_offset" = Option<i64>, Query, description = "Pagination offset"),
        ("page_limit" = Option<i64>, Query, description = "Maximum number of results to return"),
    ),
    responses(
        (status = 200, description = "List of devices", body = Vec<Device>),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
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
    let page_offset: Option<i64> = utils::parse_parameter_int(&params, "page_offset");
    let page_limit: Option<i64> = utils::parse_parameter_int(&params, "page_limit");

    match db::devices::list_devices(
        is_registered,
        last_seen_from,
        last_seen_to,
        owner,
        device_type,
        vendor,
        page_offset,
        page_limit,
    ) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing devices: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/devices/{mac_address}",
    tag = "devices",
    params(
        ("mac_address" = String, Path, description = "MAC address of the device"),
    ),
    responses(
        (status = 200, description = "Device found", body = Device),
        (status = 404, description = "Device not found"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn read(Path(mac_address): Path<String>) -> Result<Json<Device>, StatusCode> {
    match db::devices::read(mac_address) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

#[utoipa::path(
    put,
    path = "/api/devices",
    tag = "devices",
    request_body = RegisterDevicePayload,
    responses(
        (status = 201, description = "Device registered"),
        (status = 404, description = "Device not found"),
        (status = 409, description = "Device already registered"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn register(Json(payload): Json<RegisterDevicePayload>) -> impl IntoResponse {
    debug!(
        "Device registration received: mac_address={}, owner={}, device_type={}",
        payload.mac_address, payload.owner, payload.device_type
    );

    let device = match db::devices::read(payload.mac_address.clone()) {
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

    match db::devices::register(payload.mac_address, payload.owner, payload.device_type) {
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

#[utoipa::path(
    put,
    path = "/api/devices/{mac_address}",
    tag = "devices",
    params(
        ("mac_address" = String, Path, description = "MAC address of the device"),
    ),
    request_body = UpdateDevicePayload,
    responses(
        (status = 200, description = "Device updated"),
        (status = 404, description = "Device not found"),
        (status = 409, description = "Device is not registered"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn update(
    Path(mac_address): Path<String>,
    Json(payload): Json<UpdateDevicePayload>,
) -> impl IntoResponse {
    debug!(
        "Device update received: mac_address={}, owner={}, device_type={}, vendor={}",
        mac_address, payload.owner, payload.device_type, payload.vendor
    );

    let device = match db::devices::read(mac_address.clone()) {
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
            "Device is not registered, register it before modifying",
        );
    }

    match db::devices::update(mac_address, payload.owner, payload.device_type, payload.vendor) {
        Ok(_) => (axum::http::StatusCode::OK, "Device updated"),
        Err(err) => {
            error!("Error updating device in the database: {}", err);
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Error updating device in the server, check your logs",
            )
        }
    }
}

#[utoipa::path(
    delete,
    path = "/api/devices/{mac_address}",
    tag = "devices",
    params(
        ("mac_address" = String, Path, description = "MAC address of the device"),
    ),
    responses(
        (status = 200, description = "Device unregistered"),
        (status = 404, description = "Device not found"),
        (status = 409, description = "Device is not registered"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn unregister(Path(mac_address): Path<String>) -> impl IntoResponse {
    let device = match db::devices::read(mac_address.clone()) {
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

    match db::devices::unregister(mac_address) {
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

#[utoipa::path(
    get,
    path = "/api/devices/summary",
    tag = "devices",
    responses(
        (status = 200, description = "Device summary counts", body = DeviceSummary),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn summary() -> Result<Json<DeviceSummary>, StatusCode> {
    match db::devices::get_summary() {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error getting device summary: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Payload structs
#[derive(Deserialize, ToSchema)]
pub struct RegisterDevicePayload {
    mac_address: String,
    owner: String,
    device_type: String,
}

#[derive(Deserialize, ToSchema)]
pub struct UpdateDevicePayload {
    owner: String,
    device_type: String,
    vendor: String,
}
