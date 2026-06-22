use axum::{Json, http::StatusCode};

use crate::web_server::scanner_status::{ActiveScannerStatusResponse, active_response};

#[utoipa::path(
    get,
    path = "/api/snmp_scanner/status",
    operation_id = "snmp_scanner_status",
    tag = "snmp_scanner",
    responses(
        (status = 200, description = "SNMP scanner status", body = ActiveScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<ActiveScannerStatusResponse>, StatusCode> {
    active_response(crate::scanners::snmp::status::STATUS.get()).map(Json)
}
