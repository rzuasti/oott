use crate::settings::get_settings;
use clap::Parser;
use log::{LevelFilter, error, info};
use std::future::Future;

mod data;
mod db;
mod events;
mod model;
mod notifications;
mod retention;
mod scanners;
mod settings;
mod shutdown;
mod utils;
mod web_server;

#[cfg(test)]
mod tests_common;

// Command line parameters
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Config file path
    #[arg(short, long)]
    config: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Parse command line parameters and init settings
    // this is not thread safe so it needs to run just once
    let args = Args::parse();
    let config_path = args
        .config
        .unwrap_or(settings::DEFAULT_CONFIG_FILE_PATH.to_string());
    settings::init(config_path);

    // Initialize logging
    let log_level = match get_settings().log.level.as_str() {
        "off" => LevelFilter::Off,
        "error" => LevelFilter::Error,
        "warn" => LevelFilter::Warn,
        "info" => LevelFilter::Info,
        "debug" => LevelFilter::Debug,
        "trace" => LevelFilter::Trace,
        _ => LevelFilter::Error,
    };

    env_logger::Builder::new()
        .filter(None, log_level)
        .write_style(env_logger::WriteStyle::Always)
        .init();

    // Now onto the important stuff
    info!("Starting up oott");

    // Initialize database
    db::init_db().await?;

    // Initialize scanner status tracking
    scanners::arp::status::STATUS.init();
    scanners::mdns::status::STATUS.init();
    scanners::ssdp::status::STATUS.init();
    scanners::dhcp::status::STATUS.init();
    scanners::snmp::status::STATUS.init();

    // A shutdown signal (SIGTERM from Kubernetes/`docker stop`, or Ctrl-C) cancels this token; every
    // long-running task below watches it and winds down at its next safe point, so the process
    // exits promptly instead of waiting out the orchestrator's grace period and being SIGKILLed.
    let shutdown_token = tokio_util::sync::CancellationToken::new();
    tokio::spawn(shutdown::watch_for_signals(shutdown_token.clone()));

    // Start the device scanners, web server, retention cleaner, and notification delivery loop in
    // parallel. Notification delivery runs on its own task so a slow Pushover never stalls a scan.
    // Each task is wrapped so that if it exits with an error (e.g. the DHCP scanner failing to bind
    // its socket because the port is already in use) the failure is logged rather than silently
    // swallowed — otherwise a scanner just appears "off" with no explanation.
    tokio::join!(
        log_task_errors(
            "ARP scanner",
            scanners::arp::scanner::scan(shutdown_token.clone())
        ),
        log_task_errors(
            "mDNS scanner",
            scanners::mdns::scanner::listen(shutdown_token.clone())
        ),
        log_task_errors(
            "SSDP scanner",
            scanners::ssdp::scanner::listen(shutdown_token.clone())
        ),
        log_task_errors(
            "DHCP scanner",
            scanners::dhcp::scanner::listen(shutdown_token.clone())
        ),
        log_task_errors(
            "SNMP scanner",
            scanners::snmp::scanner::scan(shutdown_token.clone())
        ),
        log_task_errors("web server", web_server::serve(shutdown_token.clone())),
        retention::run(shutdown_token.clone()),
        notifications::run_delivery(shutdown_token.clone()),
    );

    // Every task has stopped; checkpoint the database so the file is left self-contained.
    info!("All tasks stopped; checkpointing the database before exit");
    if let Err(err) = db::close() {
        error!("Error checkpointing the database during shutdown: {err}");
    }
    info!("oott shut down cleanly");

    Ok(())
}

/// Await a long-running task and log its error if it exits with one. Without this the errors of
/// every task but the first were dropped by `tokio::join!`, so a scanner that failed to start
/// (for example the DHCP scanner being unable to bind port 67) reported no diagnostic at all.
async fn log_task_errors<F>(name: &str, task: F)
where
    F: Future<Output = Result<(), Box<dyn std::error::Error>>>,
{
    if let Err(err) = task.await {
        error!("{name} exited with error: {err}");
    }
}
