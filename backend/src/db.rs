pub mod devices;
pub mod notifications;

use include_dir::{Dir, include_dir};
use lazy_static::lazy_static;
use log::{debug, error};
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite_migration::Migrations;
use tokio::sync::Mutex;

use crate::settings::get_settings;

static MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/database_migrations");
static INITIALISED: Mutex<bool> = Mutex::const_new(false);

lazy_static! {
    // Define migrations. These are applied atomically.
    static ref MIGRATIONS: Migrations<'static> =
        Migrations::from_directory(&MIGRATIONS_DIR).unwrap();

    // TODO : Move pool size to configuration file
    static ref POOL: r2d2::Pool<SqliteConnectionManager> = r2d2::Pool::builder().
        max_size(10).
        build(
            r2d2_sqlite::SqliteConnectionManager::file(get_settings().database.path.as_str())
        ).unwrap();
}

pub fn get_db_connection() -> PooledConnection<SqliteConnectionManager> {
    let result = POOL.get();

    match result {
        Ok(value) => value,
        Err(error) => {
            error!("Error obtaining database connection from the pool: {error}");
            panic!("Error obtaining database connection from the pool: {error}");
        }
    }
}

pub async fn init_db() -> Result<(), String> {
    let mut initialised = INITIALISED.lock().await;
    if *initialised {
        return Ok(());
    }

    debug!("Getting database connection");

    let mut conn = get_db_connection();

    debug!("Executing database migrations if needed.");

    let result = match MIGRATIONS.to_latest(&mut conn) {
        Ok(_) => {
            debug!("Database up to date.");
            Ok(())
        }
        Err(error) => {
            error!("Error updating database: {error}");
            Err(format!("Error updating database: {error}"))
        }
    };

    *initialised = true;

    result
}
