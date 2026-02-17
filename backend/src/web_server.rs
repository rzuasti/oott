use axum::{Router, routing::get};
use log::info;
use tower_http::services::ServeDir;

pub async fn serve() -> Result<(), String> {
    info!("Starting web server");
    let static_files = ServeDir::new("./web");

    let router = Router::new()
        .route("/", get(|| async { "hello" }))
        .nest_service("/web", static_files);
    info!("Server running at http://0.0.0.0:3000");
    // Start the server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, router).await.unwrap();
    Ok(())
}
