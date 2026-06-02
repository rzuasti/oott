use axum::{Json, http::StatusCode};

use crate::web_server::scanner_status::{PassiveScannerStatusResponse, passive_response};

#[utoipa::path(
    get,
    path = "/api/mdns_scanner/status",
    tag = "mdns_scanner",
    responses(
        (status = 200, description = "mDNS scanner status", body = PassiveScannerStatusResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn status() -> Result<Json<PassiveScannerStatusResponse>, StatusCode> {
    passive_response(crate::scanners::mdns::status::get()).map(Json)
}
