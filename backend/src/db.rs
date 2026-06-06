pub mod device_events;
pub mod devices;
pub mod error;
pub mod notifications;

use include_dir::{Dir, include_dir};
use lazy_static::lazy_static;
use log::{debug, error};
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite_migration::Migrations;
use tokio::sync::Mutex;

use crate::{db::error::DbError, settings::get_settings};

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

// Appends the shared `LIMIT ? OFFSET ?` paging clause (and its bound parameters) to a list query
// when both an offset and a limit are supplied. Used by the list endpoints (devices, notifications,
// device_events) so they page identically.
pub fn apply_paging(
    sql: &mut String,
    params: &mut Vec<rusqlite::types::Value>,
    page_offset: Option<i64>,
    page_limit: Option<i64>,
) {
    if let (Some(page_offset), Some(page_limit)) = (page_offset, page_limit) {
        debug!(
            "Adding paging to list with offset={} and limit={}",
            page_offset, page_limit
        );
        sql.push_str(" LIMIT ? OFFSET ?");
        params.push(page_limit.into());
        params.push(page_offset.into());
    }
}

pub async fn init_db() -> Result<(), DbError> {
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
            Err(DbError::from(error))
        }
    };

    *initialised = true;

    result
}
