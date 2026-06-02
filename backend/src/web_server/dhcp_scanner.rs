use axum::{Json, http::StatusCode};
use chrono::Utc;
use log::error;
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct DhcpScannerStatusResponse {
    pub is_listening: bool,
    /// Seconds the listener has been running (only set when is_listening is true)
    pub listening_for_seconds: Option<f64>,
    /// Distinct devices seen in the last hour
    pub devices_seen: u64,
    /// Seconds since the last device was seen (None if none seen yet)
    pub last_device_seen_seconds_ago: Option<f64>,
}

#[utoipa::path(
    get,
    path = "/api/dhcp_scanner/status",
    tag = "dhcp_scanner",
    responses(
        (status = 200, description = "DHCP scanner status", body = DhcpScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<DhcpScannerStatusResponse>, StatusCode> {
    let snapshot = match crate::scanners::dhcp::status::get() {
        Some(s) => s,
        None => {
            error!("DHCP scanner status not initialized");
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    let now = Utc::now();

    let listening_for_seconds = if snapshot.is_listening {
        snapshot
            .listening_since
            .map(|t| (now - t).num_milliseconds() as f64 / 1000.0)
    } else {
        None
    };

    let last_device_seen_seconds_ago = snapshot
        .last_discovery_at
        .map(|t| ((now - t).num_milliseconds() as f64 / 1000.0).max(0.0));

    Ok(Json(DhcpScannerStatusResponse {
        is_listening: snapshot.is_listening,
        listening_for_seconds,
        devices_seen: snapshot.devices_last_hour,
        last_device_seen_seconds_ago,
    }))
}
