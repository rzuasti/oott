use include_dir::{Dir, include_dir};
use log::debug;
use rusqlite::{Connection, params};
use rusqlite_migration::Migrations;
use std::result::Result;
use std::sync::LazyLock;

static MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/database_migrations");

// Define migrations. These are applied atomically.
static MIGRATIONS: LazyLock<Migrations<'static>> =
    LazyLock::new(|| Migrations::from_directory(&MIGRATIONS_DIR).unwrap());

pub fn init_db() -> Result<Connection, &'static str> {
    debug!("Opening database");
    let mut conn = Connection::open("./oott.db").unwrap();

    debug!("Database open, executing migrations if needed");
    // Update the database schema, atomically
    MIGRATIONS.to_latest(&mut conn);

    debug!("Database up to date");

    Ok(conn)
}
