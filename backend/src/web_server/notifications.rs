use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, Query},
    http::StatusCode,
    response::IntoResponse,
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

pub async fn mark_as_new(Path(id): Path<i64>) -> impl IntoResponse {
    match db::notifications::mark_as_new(id) {
        Ok(_) => (StatusCode::OK, "Notification marked as new"),
        Err(err) => {
            error!("Error marking notification (id={id}) as new: {}", err);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Error updating notification in the server, check your logs",
            )
        }
    }
}

pub async fn list(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Notification>>, StatusCode> {
    let is_new: Option<bool> = utils::parse_parameter_bool(&params, "is_new");
    let page_offset: Option<i64> = utils::parse_parameter_int(&params, "page_offset");
    let page_limit: Option<i64> = utils::parse_parameter_int(&params, "page_limit");

    match db::notifications::list(is_new, page_offset, page_limit) {
        Ok(value) => Ok(Json(value)),
        Err(err) => {
            error!("Error listing notifications: {}", err);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
