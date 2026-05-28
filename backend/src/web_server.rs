use std::error::Error;

use crate::model::device_events::{DeviceEvent, DeviceEventType};
use crate::model::devices::Device;
use crate::model::notifications::{Notification, NotificationType};
use crate::settings::get_settings;
use crate::web_server::devices::RegisterDevicePayload;
use axum::extract::Request;
use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::Response;
use axum::routing::{delete, get, post, put};
use axum::{Router, http};
use log::{debug, error, info};
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use axum::Json;
use utoipa::OpenApi;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::Modify;
use utoipa_swagger_ui::SwaggerUi;

pub mod device_events;
pub mod devices;
pub mod notifications;
pub mod utils;

#[derive(OpenApi)]
#[openapi(
    info(
        title = "OOTT API",
        version = "0.1.0",
        description = "Network monitoring and alert system API"
    ),
    paths(
        test_api,
        devices::list,
        devices::read,
        devices::register,
        devices::unregister,
        notifications::list,
        notifications::read,
        notifications::read_without_flagging,
        notifications::mark_as_new,
        notifications::mark_all_as_old,
        device_events::list,
    ),
    components(schemas(
        Device,
        Notification,
        NotificationType,
        RegisterDevicePayload,
        DeviceEvent,
        DeviceEventType,
    )),
    modifiers(&SecurityAddon),
    tags(
        (name = "devices", description = "Device management"),
        (name = "notifications", description = "Notification management"),
        (name = "device_events", description = "Device event history"),
    )
)]
struct ApiDoc;

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Default::default);
        components.add_security_scheme(
            "bearer_auth",
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .build(),
            ),
        );
    }
}

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    // Allow all origins and headers for API
    let cors_layer = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([
            http::Method::GET,
            http::Method::POST,
            http::Method::PUT,
            http::Method::DELETE,
        ])
        .allow_headers([http::header::AUTHORIZATION, http::header::CONTENT_TYPE]);

    let router = Router::new()
        .route("/api/test", get(test_api))
        .route("/api/devices", get(devices::list))
        .route("/api/devices", put(devices::register))
        .route("/api/devices/{mac_address}", delete(devices::unregister))
        .route("/api/devices/{mac_address}", get(devices::read))
        .route("/api/devices/{mac_address}/events", get(device_events::list))
        .route("/api/notifications", get(notifications::list))
        .route(
            "/api/notifications/mark_all_as_old",
            post(notifications::mark_all_as_old),
        )
        .route("/api/notifications/{id}", get(notifications::read))
        .route(
            "/api/notifications/{id}/read_without_flagging",
            get(notifications::read_without_flagging),
        )
        .route(
            "/api/notifications/{id}/mark_as_new",
            post(notifications::mark_as_new),
        )
        .route_layer(axum::middleware::from_fn(auth))
        .layer(ServiceBuilder::new().layer(cors_layer))
        .route(
            "/",
            get(|| async { "Go to /web for the UI or to /api for the better UI." }),
        )
        .nest_service("/web", static_files)
        .merge(SwaggerUi::new("/api/docs").url("/api/docs/openapi.json", ApiDoc::openapi()));

    let web_server_host_and_port = format!(
        "{}:{}",
        get_settings().web_server.ip_address,
        get_settings().web_server.port
    );

    info!("Web server starting at http://{}", web_server_host_and_port);
    // Start the server
    let listener = tokio::net::TcpListener::bind(web_server_host_and_port).await?;

    debug!("Web server bound to IP and port");

    axum::serve(listener, router).await?;
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/test",
    responses(
        (status = 200, description = "API is reachable", body = String),
    ),
    security(("bearer_auth" = []))
)]
async fn test_api() -> Result<Json<String>, StatusCode> {
    Ok(Json("OOTT_API_OK".to_string()))
}

async fn auth(request: Request, next: Next) -> Result<Response, StatusCode> {
    let auth_header = request
        .headers()
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok());

    let auth_header = match auth_header {
        Some(value) => value,
        None => return Err(StatusCode::UNAUTHORIZED),
    };

    let mut valid_header = "Bearer ".to_string();
    let api_key = get_settings().web_server.api_key.as_str();
    if api_key == "CHANGE_ME" {
        error!("The configured api_key is still 'CHANGE_ME', please change it.");
        return Err(StatusCode::INTERNAL_SERVER_ERROR);
    }

    valid_header.push_str(api_key);

    if auth_header == valid_header {
        Ok(next.run(request).await)
    } else {
        Err(StatusCode::UNAUTHORIZED)
    }
}
