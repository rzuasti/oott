pub mod device_events;
pub mod devices;
pub mod error;
pub mod notifications;
pub mod push_tokens;

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
                .with_init(|conn| {
                    // Per-connection pragmas. These must be set on every pooled connection (they
                    // are not persisted in the database file). The WAL journal mode is NOT set
                    // here: it is a persistent property of the database file and is enabled once
                    // in `init_db`. Setting it per connection instead races several concurrent WAL
                    // switches when r2d2 eagerly opens the pool at startup, producing transient
                    // "disk I/O error" / "database is locked" failures.
                    // - busy_timeout makes a connection wait for a lock rather than failing
                    //   immediately with "database is locked".
                    // - synchronous=NORMAL is the safe, recommended pairing with WAL and avoids
                    //   an fsync on every commit (the default FULL fsyncs on each write).
                    // - foreign_keys are off by default in SQLite and must be set per connection.
                    conn.execute_batch(
                        "PRAGMA busy_timeout = 5000;
                         PRAGMA synchronous = NORMAL;
                         PRAGMA foreign_keys = ON;",
                    )
                })
        ).unwrap();
}

pub fn get_db_connection() -> Result<PooledConnection<SqliteConnectionManager>, DbError> {
    POOL.get().map_err(|error| {
        error!("Error obtaining database connection from the pool: {error}");
        DbError::from(error)
    })
}

// Runs a blocking database operation on tokio's blocking thread pool so it never stalls an async
// worker thread. The DB layer uses synchronous `rusqlite`, so axum handlers must wrap their DB
// work in this rather than calling `db::*` functions inline.
pub async fn run_blocking<F, T>(f: F) -> T
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
{
    tokio::task::spawn_blocking(f)
        .await
        .expect("blocking database task panicked")
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

    let mut conn = get_db_connection()?;

    // Enable WAL once on the shared database file. WAL is a persistent property of the file, so it
    // survives across connections and restarts and only needs to be set a single time, here, before
    // the scanners and web server start. Doing it per pooled connection instead races several
    // concurrent WAL switches at startup ("disk I/O error" / "database is locked").
    debug!("Ensuring the database is in WAL journal mode.");
    conn.execute_batch("PRAGMA journal_mode = WAL;")?;

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

/// Fold the write-ahead log back into the main database file on shutdown.
///
/// SQLite checkpoints the WAL on its own, but doing it explicitly when stopping leaves the
/// database file self-contained — no `-wal`/`-shm` sidecars still carrying committed data — which
/// is the tidy counterpart to `init_db` enabling WAL at startup. `TRUNCATE` checkpoints and then
/// shrinks the WAL file back to empty.
pub fn close() -> Result<(), DbError> {
    let conn = get_db_connection()?;
    conn.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn close_checkpoints_without_error() {
        tests_common::setup().await;
        // The shutdown checkpoint must succeed against an initialised (WAL) database.
        close().expect("shutdown checkpoint should succeed");
    }
}
