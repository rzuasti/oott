use crate::db;
use crate::settings::get_settings;
use include_dir::{Dir, include_dir};
use log::{LevelFilter, debug, info};
use tokio::sync::Mutex;

static TEST_MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/tests/database_setup");

// Use a Mutex bool as semaphore to ensure single initialization
static INITIALISED: Mutex<bool> = Mutex::const_new(false);

pub async fn setup() {
    debug!("About to setup testing.");
    let mut initialised = INITIALISED.lock().await;
    if *initialised {
        debug!("Testing was already initialised, nothing to do.");
        return;
    }

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

    // Initialize database
    db::init_db().await.unwrap();
    info!("Initializing database for testing.");
    let conn = db::get_db_connection();
    debug!("Running database setup scripts for testing.");

    for entry in TEST_MIGRATIONS_DIR.entries() {
        if entry.path().extension().map_or(false, |ext| ext == "sql") {
            debug!("About to run {}", entry.path().display());

            if entry.path().extension().map_or(false, |ext| ext == "sql") {
                let sql = entry.as_file().unwrap().contents_utf8().unwrap();
                conn.execute_batch(&sql).unwrap_or_else(|err| {
                    panic!("Error executing script: {}", err);
                });
            };
        }
    }

    debug!("Database setup for testing.");

    // Done
    *initialised = true;
}
