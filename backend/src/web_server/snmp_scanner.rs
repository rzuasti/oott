use axum::{Json, http::StatusCode};
use chrono::Utc;
use log::error;
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct SnmpScannerStatusResponse {
    pub is_running: bool,
    /// Seconds the current poll has been running (only set when is_running is true)
    pub running_for_seconds: Option<f64>,
    /// Seconds until the next poll starts (only set when is_running is false; clamped to 0)
    pub next_run_in_seconds: Option<f64>,
}

#[utoipa::path(
    get,
    path = "/api/snmp_scanner/status",
    tag = "snmp_scanner",
    responses(
        (status = 200, description = "SNMP scanner status", body = SnmpScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<SnmpScannerStatusResponse>, StatusCode> {
    let snapshot = match crate::scanners::snmp::status::get() {
        Some(s) => s,
        None => {
            error!("SNMP scanner status not initialized");
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

    Ok(Json(SnmpScannerStatusResponse {
        is_running: snapshot.is_running,
        running_for_seconds,
        next_run_in_seconds,
    }))
}
