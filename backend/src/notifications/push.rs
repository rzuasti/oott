use log::debug;
use serde::{Deserialize, Serialize};

use crate::db;
use crate::notifications::error::DeliveryError;
use crate::settings::Push;

// The relay request body. Only the already-sanitized title/body travels — no `data`, no MAC, no IP
// (see push_notifications.md, "No private data in payloads").
#[derive(Serialize)]
struct RelayNotification {
    title: String,
    body: String,
}

#[derive(Serialize)]
struct RelayRequest {
    tokens: Vec<String>,
    notification: RelayNotification,
}

// Per-token result the relay returns so dead tokens can be pruned. `status` is one of
// `ok` / `unregistered` / `invalid`.
#[derive(Deserialize)]
struct RelayTokenResult {
    token: String,
    status: String,
}

#[derive(Deserialize)]
struct RelayResponse {
    #[serde(default)]
    results: Vec<RelayTokenResult>,
}

// FCM statuses for tokens that can never be delivered to again; the backend prunes these.
fn is_dead_status(status: &str) -> bool {
    matches!(status, "unregistered" | "invalid")
}

fn dead_tokens(results: &[RelayTokenResult]) -> Vec<String> {
    results
        .iter()
        .filter(|result| is_dead_status(&result.status))
        .map(|result| result.token.clone())
        .collect()
}

/// Deliver a notification to all registered devices through the project-operated push relay. Loads
/// the stored tokens, forwards only the already-sanitized title/body, and prunes any tokens the
/// relay reports as dead. Returns the number of devices the relay confirmed delivery to. Best-effort:
/// a relay/network failure returns an error (logged by the caller) but never loses the event, which
/// is already persisted in the notifications table.
pub async fn send(config: &Push, title: String, body: String) -> Result<usize, DeliveryError> {
    let stored = db::run_blocking(db::push_tokens::list).await?;
    if stored.is_empty() {
        debug!("No push tokens registered; nothing to deliver via the push relay");
        return Ok(0);
    }

    let request = RelayRequest {
        tokens: stored.into_iter().map(|token| token.token).collect(),
        notification: RelayNotification { title, body },
    };
    debug!(
        "Delivering push to {} token(s) via relay",
        request.tokens.len()
    );

    let response = reqwest::Client::new()
        .post(config.relay_url.as_str())
        .json(&request)
        .send()
        .await?
        .error_for_status()?;

    let parsed: RelayResponse = response.json().await?;
    let dead = dead_tokens(&parsed.results);
    if !dead.is_empty() {
        debug!("Pruning {} dead push token(s) reported by the relay", dead.len());
        db::run_blocking(move || db::push_tokens::delete_many(&dead)).await?;
    }

    let delivered = parsed
        .results
        .iter()
        .filter(|result| result.status == "ok")
        .count();
    Ok(delivered)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::push_tokens::PushPlatform;
    use crate::tests_common;
    use axum::{Json, Router, routing::post};
    use serde_json::json;

    #[test]
    fn dead_tokens_selects_unregistered_and_invalid_only() {
        let results = vec![
            RelayTokenResult {
                token: "ok-1".into(),
                status: "ok".into(),
            },
            RelayTokenResult {
                token: "dead-1".into(),
                status: "unregistered".into(),
            },
            RelayTokenResult {
                token: "dead-2".into(),
                status: "invalid".into(),
            },
        ];
        assert_eq!(
            dead_tokens(&results),
            vec!["dead-1".to_string(), "dead-2".to_string()]
        );
    }

    #[tokio::test]
    async fn send_prunes_tokens_the_relay_reports_dead() {
        tests_common::setup().await;

        let live = "push-send-live";
        let dead = "push-send-dead";
        db::push_tokens::upsert(live, PushPlatform::Android).unwrap();
        db::push_tokens::upsert(dead, PushPlatform::Ios).unwrap();

        // A mock relay that marks the dead token unregistered and the live one ok.
        let app = Router::new().route(
            "/v1/push",
            post(|Json(_body): Json<serde_json::Value>| async move {
                Json(json!({
                    "results": [
                        { "token": "push-send-live", "status": "ok" },
                        { "token": "push-send-dead", "status": "unregistered" },
                    ]
                }))
            }),
        );
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        let config = Push {
            relay_url: format!("http://{addr}/v1/push"),
        };
        let delivered = send(&config, "title".into(), "body".into()).await.unwrap();
        assert_eq!(delivered, 1, "Only the live token should count as delivered");

        let all = db::push_tokens::list().unwrap();
        assert!(
            all.iter().any(|token| token.token == live),
            "Live token must remain after delivery"
        );
        assert!(
            !all.iter().any(|token| token.token == dead),
            "A token the relay reports dead must be pruned"
        );
    }
}
