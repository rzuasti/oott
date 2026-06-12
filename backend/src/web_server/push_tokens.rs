use axum::extract::Path;
use axum::response::IntoResponse;
use axum::{Json, http::StatusCode};
use log::error;
use serde::Deserialize;
use utoipa::ToSchema;

use crate::db;
use crate::model::push_tokens::PushPlatform;

#[utoipa::path(
    put,
    path = "/api/push_tokens",
    tag = "push_tokens",
    request_body = RegisterPushTokenPayload,
    responses(
        (status = 200, description = "Push token registered or refreshed"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn register(Json(payload): Json<RegisterPushTokenPayload>) -> impl IntoResponse {
    db::run_blocking(
        move || match db::push_tokens::upsert(&payload.token, payload.platform) {
            Ok(_) => (StatusCode::OK, "Push token registered"),
            Err(err) => {
                error!("Error registering push token in the database: {err}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Error registering push token in the server, check your logs",
                )
            }
        },
    )
    .await
}

#[utoipa::path(
    delete,
    path = "/api/push_tokens/{token}",
    tag = "push_tokens",
    params(
        ("token" = String, Path, description = "The push token to unregister"),
    ),
    responses(
        (status = 200, description = "Push token unregistered"),
        (status = 500, description = "Internal server error"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn unregister(Path(token): Path<String>) -> impl IntoResponse {
    db::run_blocking(move || match db::push_tokens::delete(&token) {
        // Deleting an unknown token is a no-op and still reports success, so the app can call
        // unregister idempotently (e.g. when disabling push) without handling a "not found".
        Ok(_) => (StatusCode::OK, "Push token unregistered"),
        Err(err) => {
            error!("Error unregistering push token in the database: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Error unregistering push token in the server, check your logs",
            )
        }
    })
    .await
}

// Payload structs
#[derive(Deserialize, ToSchema)]
pub struct RegisterPushTokenPayload {
    pub token: String,
    pub platform: PushPlatform,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn register_then_unregister_round_trip() {
        tests_common::setup().await;

        let token = "api-push-token-1".to_string();

        let response = register(Json(RegisterPushTokenPayload {
            token: token.clone(),
            platform: PushPlatform::Android,
        }))
        .await
        .into_response();
        assert_eq!(response.status(), StatusCode::OK);
        assert!(
            db::push_tokens::list()
                .unwrap()
                .iter()
                .any(|t| t.token == token),
            "Registered token should be stored"
        );

        let response = unregister(Path(token.clone())).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
        assert!(
            !db::push_tokens::list()
                .unwrap()
                .iter()
                .any(|t| t.token == token),
            "Unregistered token should be removed"
        );
    }

    #[tokio::test]
    async fn unregister_is_idempotent_for_unknown_tokens() {
        tests_common::setup().await;

        let response = unregister(Path("api-push-token-never-registered".to_string()))
            .await
            .into_response();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
