pub mod devices;

use include_dir::{Dir, include_dir};
use log::{debug, error};
use rusqlite::Connection;
use rusqlite_migration::Migrations;
use std::result::Result;
use std::sync::LazyLock;

static MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/database_migrations");

// Define migrations. These are applied atomically.
static MIGRATIONS: LazyLock<Migrations<'static>> =
    LazyLock::new(|| Migrations::from_directory(&MIGRATIONS_DIR).unwrap());

pub fn init_db() -> Result<Connection, String> {
    debug!("Opening database.");
    let mut conn = match Connection::open("./oott.db") {
        Ok(value) => value,
        Err(error) => {
            error!("Error opening database (oott.db): {error}");
            return Err(format!("Error opening database (oott.db): {error}"));
        }
    };

    debug!("Database open, executing migrations if needed.");
    // Update the database schema, atomically
    match MIGRATIONS.to_latest(&mut conn) {
        Ok(_) => {
            debug!("Database up to date.");
            Ok(conn)
        }
        Err(error) => {
            error!("Error updating database: {error}");
            Err(format!("Error updating database: {error}"))
        }
    }
}
