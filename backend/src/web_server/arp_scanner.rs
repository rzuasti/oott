use axum::{Json, http::StatusCode};
use chrono::Utc;
use log::error;
use serde::Serialize;
use utoipa::ToSchema;

use crate::arp_scanner_status;

#[derive(Serialize, ToSchema)]
pub struct ArpScannerStatusResponse {
    pub is_running: bool,
    /// Seconds the current scan has been running (only set when is_running is true)
    pub running_for_seconds: Option<f64>,
    /// Seconds until the next scan starts (only set when is_running is false; clamped to 0)
    pub next_run_in_seconds: Option<f64>,
}

#[utoipa::path(
    get,
    path = "/api/arp_scanner/status",
    tag = "arp_scanner",
    responses(
        (status = 200, description = "ARP scanner status", body = ArpScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<ArpScannerStatusResponse>, StatusCode> {
    let snapshot = match arp_scanner_status::get() {
        Some(s) => s,
        None => {
            error!("ARP scanner status not initialized");
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    let now = Utc::now();

    let (running_for_seconds, next_run_in_seconds) = if snapshot.is_running {
        let running_for = snapshot
            .scan_started_at
            .map(|t| (now - t).num_milliseconds() as f64 / 1000.0);
        (running_for, None)
    } else {
        let next_run_in = snapshot.next_scan_at.map(|t| {
            let secs = (t - now).num_milliseconds() as f64 / 1000.0;
            secs.max(0.0)
        });
        (None, next_run_in)
    };

    Ok(Json(ArpScannerStatusResponse {
        is_running: snapshot.is_running,
        running_for_seconds,
        next_run_in_seconds,
    }))
}
