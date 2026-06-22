use axum::{Json, http::StatusCode};

use crate::web_server::scanner_status::{PassiveScannerStatusResponse, passive_response};

#[utoipa::path(
    get,
    path = "/api/dhcp_scanner/status",
    operation_id = "dhcp_scanner_status",
    tag = "dhcp_scanner",
    responses(
        (status = 200, description = "DHCP scanner status", body = PassiveScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<PassiveScannerStatusResponse>, StatusCode> {
    passive_response(crate::scanners::dhcp::status::STATUS.get()).map(Json)
}
