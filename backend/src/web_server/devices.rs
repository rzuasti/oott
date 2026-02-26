use std::collections::HashMap;

use axum::{Json, extract::Query, http::StatusCode};
use chrono::{DateTime, Utc};
use log::error;

use crate::{db, model::devices::Device};

use crate::web_server::utils;

pub async fn list_devices(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Device>>, StatusCode> {
    let is_registered: Option<bool> = utils::parse_parameter_bool(&params, "is_registered");
    let last_seen_from: Option<DateTime<Utc>> =
        utils::parse_parameter_date(&params, "last_seen_from");
    let last_seen_to: Option<DateTime<Utc>> = utils::parse_parameter_date(&params, "last_seen_to");
    let owner: Option<String> = utils::parse_parameter_string(&params, "owner");
    let device_type: Option<String> = utils::parse_parameter_string(&params, "device_type");
    let vendor: Option<String> = utils::parse_parameter_string(&params, "vendor");

    match db::devices::list_devices(
        is_registered,
        last_seen_from,
        last_seen_to,
        owner,
        device_type,
        vendor,
    ) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing devices: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
