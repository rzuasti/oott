use axum::http::StatusCode;
use chrono::Utc;
use serde::Serialize;
use utoipa::ToSchema;

use crate::scanners::common::active_status::ActiveSnapshot;
use crate::scanners::common::passive_status::PassiveSnapshot;

/// API status of an active (polling) scanner — ARP and SNMP.
#[derive(Serialize, ToSchema)]
pub struct ActiveScannerStatusResponse {
    pub is_running: bool,
    /// Seconds the current scan has been running (only set when is_running is true)
    pub running_for_seconds: Option<f64>,
    /// Seconds until the next scan starts (only set when is_running is false; clamped to 0)
    pub next_run_in_seconds: Option<f64>,
    /// Number of devices found by the last successful scan (None if none completed yet)
    pub last_scan_devices_seen: Option<u64>,
    /// Seconds since the last successful scan completed (None if none completed yet)
    pub last_scan_seconds_ago: Option<f64>,
}

/// API status of a passive (listening) scanner — mDNS, SSDP and DHCP.
#[derive(Serialize, ToSchema)]
pub struct PassiveScannerStatusResponse {
    pub is_listening: bool,
    /// Seconds the listener has been running (only set when is_listening is true)
    pub listening_for_seconds: Option<f64>,
    /// Distinct devices seen in the last hour
    pub devices_seen: u64,
    /// Seconds since the last device was seen (None if none seen yet)
    pub last_device_seen_seconds_ago: Option<f64>,
}

/// Non-negative seconds from `earlier` to `later` (0 if `later` is before `earlier`).
fn seconds_between(earlier: chrono::DateTime<Utc>, later: chrono::DateTime<Utc>) -> f64 {
    ((later - earlier).num_milliseconds() as f64 / 1000.0).max(0.0)
}

/// Build the response for an active scanner. `None` (status tracking never initialized) maps to a
/// 500.
pub fn active_response(
    snapshot: Option<ActiveSnapshot>,
) -> Result<ActiveScannerStatusResponse, StatusCode> {
    let snapshot = snapshot.ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;
    let now = Utc::now();

    let (running_for_seconds, next_run_in_seconds) = if snapshot.is_running {
        let running_for = snapshot
            .scan_started_at
            .map(|t| (now - t).num_milliseconds() as f64 / 1000.0);
        (running_for, None)
    } else {
        let next_run_in = snapshot.next_scan_at.map(|t| seconds_between(now, t));
        (None, next_run_in)
    };

    Ok(ActiveScannerStatusResponse {
        is_running: snapshot.is_running,
        running_for_seconds,
        next_run_in_seconds,
        last_scan_devices_seen: snapshot.last_scan_devices_seen,
        last_scan_seconds_ago: snapshot.last_scan_at.map(|t| seconds_between(t, now)),
    })
}

/// Build the response for a passive scanner. `None` (status tracking never initialized) maps to a
/// 500.
pub fn passive_response(
    snapshot: Option<PassiveSnapshot>,
) -> Result<PassiveScannerStatusResponse, StatusCode> {
    let snapshot = snapshot.ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;
    let now = Utc::now();

    let listening_for_seconds = if snapshot.is_listening {
        snapshot
            .listening_since
            .map(|t| (now - t).num_milliseconds() as f64 / 1000.0)
    } else {
        None
    };

    Ok(PassiveScannerStatusResponse {
        is_listening: snapshot.is_listening,
        listening_for_seconds,
        devices_seen: snapshot.devices_last_hour,
        last_device_seen_seconds_ago: snapshot.last_discovery_at.map(|t| seconds_between(t, now)),
    })
}
