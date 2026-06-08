use serde::Serialize;
use utoipa::ToSchema;

// Front-end-facing view of the backend configuration. Only the settings the UI
// needs to adapt itself are exposed here, grouped by area so the shape can grow
// without breaking existing fields. Today it carries just the notification
// method, which gates the per-device push toggle in the settings screen.
#[derive(Clone, Serialize, ToSchema)]
pub struct Config {
    pub notifications: NotificationConfig,
}

#[derive(Clone, Serialize, ToSchema)]
pub struct NotificationConfig {
    // The configured delivery method (e.g. "push", "pushover", "none").
    pub method: String,
}
