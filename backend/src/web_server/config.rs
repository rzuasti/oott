use axum::Json;

use crate::model::config::{Config, NotificationConfig};
use crate::settings::get_settings;

#[utoipa::path(
    get,
    path = "/api/config",
    operation_id = "config_read",
    tag = "config",
    responses(
        (status = 200, description = "Front-end configuration", body = Config),
    ),
    security(("bearer_auth" = []))
)]
pub async fn read() -> Json<Config> {
    let settings = get_settings();
    Json(Config {
        notifications: NotificationConfig {
            method: settings.notifications.method.clone(),
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn config_reports_the_configured_notification_method() {
        tests_common::setup().await;

        let Json(config) = read().await;

        assert_eq!(
            config.notifications.method,
            get_settings().notifications.method,
            "The endpoint should echo the backend's configured notification method"
        );
    }
}
