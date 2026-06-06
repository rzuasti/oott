use std::error::Error;
use std::path::{Path, PathBuf};

use crate::model::device_events::{DeviceEvent, DeviceEventScanner, DeviceEventType};
use crate::model::devices::{Device, DeviceListResponse, DeviceSummary};
use crate::model::notifications::{Notification, NotificationListResponse, NotificationType};
use crate::settings::get_settings;
use crate::web_server::devices::{RegisterDevicePayload, UpdateDevicePayload};
use crate::web_server::scanner_status::{
    ActiveScannerStatusResponse, PassiveScannerStatusResponse,
};
use axum::Json;
use axum::extract::Request;
use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::{Redirect, Response};
use axum::routing::{delete, get, post, put};
use axum::{Router, http};
use log::{debug, error, info};
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use utoipa::Modify;
use utoipa::OpenApi;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa_swagger_ui::SwaggerUi;

pub mod arp_scanner;
pub mod device_events;
pub mod devices;
pub mod dhcp_scanner;
pub mod mdns_scanner;
pub mod notifications;
pub mod scanner_status;
pub mod snmp_scanner;
pub mod ssdp_scanner;
pub mod utils;

#[derive(OpenApi)]
#[openapi(
    info(
        title = "OOTT API",
        // version is intentionally omitted: utoipa fills it from the crate
        // version (CARGO_PKG_VERSION, i.e. backend/Cargo.toml) automatically.
        description = "Network monitoring and alert system API"
    ),
    paths(
        test_api,
        devices::list,
        devices::summary,
        devices::read,
        devices::register,
        devices::update,
        devices::unregister,
        notifications::list,
        notifications::read,
        notifications::read_without_flagging,
        notifications::mark_as_new,
        notifications::mark_all_as_old,
        device_events::list,
        arp_scanner::status,
        mdns_scanner::status,
        ssdp_scanner::status,
        dhcp_scanner::status,
        snmp_scanner::status,
    ),
    components(schemas(
        Device,
        DeviceListResponse,
        DeviceSummary,
        Notification,
        NotificationListResponse,
        NotificationType,
        RegisterDevicePayload,
        UpdateDevicePayload,
        DeviceEvent,
        DeviceEventType,
        DeviceEventScanner,
        ActiveScannerStatusResponse,
        PassiveScannerStatusResponse,
    )),
    modifiers(&SecurityAddon),
    tags(
        (name = "devices", description = "Device management"),
        (name = "notifications", description = "Notification management"),
        (name = "device_events", description = "Device event history"),
        (name = "arp_scanner", description = "ARP scanner process status"),
        (name = "mdns_scanner", description = "mDNS/Bonjour scanner process status"),
        (name = "ssdp_scanner", description = "SSDP/UPnP scanner process status"),
        (name = "dhcp_scanner", description = "DHCP scanner process status"),
        (name = "snmp_scanner", description = "SNMP scanner process status"),
    )
)]
struct ApiDoc;

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Default::default);
        components.add_security_scheme(
            "bearer_auth",
            SecurityScheme::Http(HttpBuilder::new().scheme(HttpAuthScheme::Bearer).build()),
        );
    }
}

/// Resolve the directory that holds the bundled front-end (Flutter web) assets.
///
/// The assets are installed next to the binary at `<exe_dir>/../share/oott/web`
/// (see the Nix package definition). When the executable location cannot be
/// determined we fall back to `./web` relative to the current directory.
fn resolve_web_root(exe_dir: Option<&Path>) -> PathBuf {
    match exe_dir {
        Some(dir) => dir.join("../share/oott/web"),
        None => PathBuf::from("./web"),
    }
}

pub async fn serve() -> Result<(), Box<dyn Error>> {
    info!("Starting web server");
    let exe = std::env::current_exe().ok();
    let web_root = resolve_web_root(exe.as_deref().and_then(Path::parent));
    info!("Serving front-end assets from {}", web_root.display());
    let static_files = ServeDir::new(web_root);

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
        .route("/api/devices/summary", get(devices::summary))
        .route("/api/devices/{mac_address}", delete(devices::unregister))
        .route("/api/devices/{mac_address}", get(devices::read))
        .route("/api/devices/{mac_address}", put(devices::update))
        .route(
            "/api/devices/{mac_address}/events",
            get(device_events::list),
        )
        .route("/api/arp_scanner/status", get(arp_scanner::status))
        .route("/api/mdns_scanner/status", get(mdns_scanner::status))
        .route("/api/ssdp_scanner/status", get(ssdp_scanner::status))
        .route("/api/dhcp_scanner/status", get(dhcp_scanner::status))
        .route("/api/snmp_scanner/status", get(snmp_scanner::status))
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
        // Send visitors straight to the UI; the bare "/" has no content of its own.
        .route("/", get(|| async { Redirect::temporary("/web") }))
        // The API explorer lives at /api/docs; redirect the bare /api for convenience.
        .route("/api", get(|| async { Redirect::temporary("/api/docs") }))
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn web_root_is_relative_to_the_executable() {
        let root = resolve_web_root(Some(Path::new("/nix/store/abc-oott/bin")));
        assert_eq!(
            root,
            PathBuf::from("/nix/store/abc-oott/bin/../share/oott/web")
        );
    }

    #[test]
    fn web_root_falls_back_to_local_dir_without_an_executable() {
        assert_eq!(resolve_web_root(None), PathBuf::from("./web"));
    }

    #[test]
    fn openapi_version_tracks_the_crate_version() {
        // The OpenAPI spec must report the crate version (backend/Cargo.toml)
        // rather than a separately maintained literal.
        let openapi = <ApiDoc as OpenApi>::openapi();
        assert_eq!(openapi.info.version, env!("CARGO_PKG_VERSION"));
    }
}
