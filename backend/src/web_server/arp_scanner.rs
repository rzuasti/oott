use axum::{Json, http::StatusCode};

use crate::web_server::scanner_status::{ActiveScannerStatusResponse, active_response};

#[utoipa::path(
    get,
    path = "/api/arp_scanner/status",
    tag = "arp_scanner",
    responses(
        (status = 200, description = "ARP scanner status", body = ActiveScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<ActiveScannerStatusResponse>, StatusCode> {
    active_response(crate::scanners::arp::status::get()).map(Json)
}
