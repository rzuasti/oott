use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, Query},
    http::StatusCode,
};
use log::error;

use crate::{db, model::notifications::Notification, web_server::utils};

pub async fn read(Path(id): Path<i64>) -> Result<Json<Notification>, StatusCode> {
    match db::notifications::mark_as_old(id) {
        Ok(_) => {}
        Err(err) => {
            error!("Error marking notification (id={id}) as old: {}", err);
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    match db::notifications::read(id) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn read_without_flagging(Path(id): Path<i64>) -> Result<Json<Notification>, StatusCode> {
    match db::notifications::read(id) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn list(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Notification>>, StatusCode> {
    let page_offset: Option<i64> = utils::parse_parameter_int(&params, "page_offset");
    let page_limit: Option<i64> = utils::parse_parameter_int(&params, "page_limit");

    match db::notifications::list(page_offset, page_limit) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing notifications: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
