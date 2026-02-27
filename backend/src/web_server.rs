use std::error::Error;

use crate::settings::get_settings;
use axum::extract::Request;
use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::Response;
use axum::routing::{delete, get, put};
use axum::{Router, http};
use log::{debug, error, info};
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;

pub mod devices;
pub mod notifications;
pub mod utils;

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    // Allow all origins and headers for API
    let cors_layer = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers([http::header::AUTHORIZATION, http::header::CONTENT_TYPE]);

    let router = Router::new()
        .route("/api/devices", get(devices::list))
        .route("/api/devices", put(devices::register))
        .route("/api/devices/{mac_address}", delete(devices::unregister))
        .route("/api/devices/{mac_address}", get(devices::read))
        .route("/api/notifications", get(notifications::list))
        .route("/api/notifications/{id}", get(notifications::read))
        .route(
            "/api/notifications/{id}/read_without_flagging",
            get(notifications::read_without_flagging),
        )
        .route_layer(axum::middleware::from_fn(auth))
        .layer(ServiceBuilder::new().layer(cors_layer))
        .route(
            "/",
            get(|| async { "Go to /web for the UI or to /api for the better UI." }),
        )
        .nest_service("/web", static_files);

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
