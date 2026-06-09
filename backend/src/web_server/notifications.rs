use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, Query},
    http::StatusCode,
    response::IntoResponse,
};
use log::error;
use serde::Serialize;
use utoipa::ToSchema;

use crate::{
    db, notifications,
    model::notifications::{Notification, NotificationListResponse},
    web_server::utils,
};

/// Result of a test-notification request: how many devices the relay confirmed delivery to.
#[derive(Serialize, ToSchema)]
pub struct TestNotificationResponse {
    pub delivered: usize,
}

#[utoipa::path(
    get,
    path = "/api/notifications/{id}",
    tag = "notifications",
    params(
        ("id" = i64, Path, description = "Notification ID"),
    ),
    responses(
        (status = 200, description = "Notification found and marked as read", body = Notification),
        (status = 404, description = "Notification not found"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn read(Path(id): Path<i64>) -> Result<Json<Notification>, StatusCode> {
    db::run_blocking(move || {
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
    })
    .await
}

#[utoipa::path(
    get,
    path = "/api/notifications/{id}/read_without_flagging",
    tag = "notifications",
    params(
        ("id" = i64, Path, description = "Notification ID"),
    ),
    responses(
        (status = 200, description = "Notification found without marking as read", body = Notification),
        (status = 404, description = "Notification not found"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn read_without_flagging(Path(id): Path<i64>) -> Result<Json<Notification>, StatusCode> {
    db::run_blocking(move || match db::notifications::read(id) {
        Some(value) => Ok(Json(value)),
        None => Err(StatusCode::NOT_FOUND),
    })
    .await
}

#[utoipa::path(
    post,
    path = "/api/notifications/{id}/mark_as_new",
    tag = "notifications",
    params(
        ("id" = i64, Path, description = "Notification ID"),
    ),
    responses(
        (status = 200, description = "Notification marked as new"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn mark_as_new(Path(id): Path<i64>) -> impl IntoResponse {
    db::run_blocking(move || match db::notifications::mark_as_new(id) {
        Ok(_) => (StatusCode::OK, "Notification marked as new"),
        Err(err) => {
            error!("Error marking notification (id={id}) as new: {}", err);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Error updating notification in the server, check your logs",
            )
        }
    })
    .await
}

#[utoipa::path(
    post,
    path = "/api/notifications/mark_all_as_old",
    tag = "notifications",
    responses(
        (status = 200, description = "All notifications marked as old"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn mark_all_as_old() -> impl IntoResponse {
    db::run_blocking(move || match db::notifications::mark_all_as_old() {
        Ok(_) => (StatusCode::OK, "All notifications marked as old"),
        Err(err) => {
            error!("Error marking all notifications as old: {}", err);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Error updating notifications in the server, check your logs",
            )
        }
    })
    .await
}

#[utoipa::path(
    post,
    path = "/api/notifications/test",
    tag = "notifications",
    responses(
        (status = 200, description = "Test notification dispatched", body = TestNotificationResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn send_test() -> Result<Json<TestNotificationResponse>, StatusCode> {
    match notifications::send_test_push().await {
        Ok(delivered) => Ok(Json(TestNotificationResponse { delivered })),
        Err(err) => {
            error!("Error sending test push notification: {err}");
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/notifications",
    tag = "notifications",
    params(
        ("is_new" = Option<bool>, Query, description = "Filter by new/read status"),
        ("page_offset" = Option<i64>, Query, description = "Pagination offset"),
        ("page_limit" = Option<i64>, Query, description = "Maximum number of results to return"),
    ),
    responses(
        (status = 200, description = "List of notifications", body = NotificationListResponse),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn list(
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<NotificationListResponse>, StatusCode> {
    let is_new: Option<bool> = utils::parse_parameter(&params, "is_new");
    let page_offset: Option<i64> = utils::parse_parameter(&params, "page_offset");
    let page_limit: Option<i64> = utils::parse_parameter(&params, "page_limit");

    db::run_blocking(move || {
        let items = match db::notifications::list(is_new, page_offset, page_limit) {
            Ok(value) => value,
            Err(err) => {
                error!("Error listing notifications: {}", err);
                return Err(StatusCode::INTERNAL_SERVER_ERROR);
            }
        };

        let total_count = match db::notifications::count(is_new) {
            Ok(value) => value,
            Err(err) => {
                error!("Error counting notifications: {}", err);
                return Err(StatusCode::INTERNAL_SERVER_ERROR);
            }
        };

        Ok(Json(NotificationListResponse { items, total_count }))
    })
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn send_test_succeeds_with_no_registered_devices() {
        tests_common::setup().await;

        // Clear any tokens left by other tests so the relay is never contacted (the no-op path),
        // keeping this hermetic; actual relay delivery + pruning is covered in the
        // notifications::push tests with a mock relay.
        let tokens: Vec<String> = db::push_tokens::list()
            .unwrap()
            .into_iter()
            .map(|token| token.token)
            .collect();
        if !tokens.is_empty() {
            db::push_tokens::delete_many(&tokens).unwrap();
        }

        let result = send_test()
            .await
            .expect("test send should succeed when no devices are registered");
        assert_eq!(result.0.delivered, 0, "No devices means nothing delivered");
    }
}
