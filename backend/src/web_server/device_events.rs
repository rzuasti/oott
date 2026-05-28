use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, Query},
    http::StatusCode,
};
use log::error;

use crate::{db, model::device_events::DeviceEvent, web_server::utils};

#[utoipa::path(
    get,
    path = "/api/devices/{mac_address}/events",
    tag = "device_events",
    params(
        ("mac_address" = String, Path, description = "MAC address of the device"),
        ("page_offset" = Option<i64>, Query, description = "Pagination offset"),
        ("page_limit" = Option<i64>, Query, description = "Maximum number of results to return"),
    ),
    responses(
        (status = 200, description = "List of device events", body = Vec<DeviceEvent>),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn list(
    Path(mac_address): Path<String>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<DeviceEvent>>, StatusCode> {
    let page_offset: Option<i64> = utils::parse_parameter_int(&params, "page_offset");
    let page_limit: Option<i64> = utils::parse_parameter_int(&params, "page_limit");

    match db::device_events::list(Some(mac_address), page_offset, page_limit) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing device events: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
