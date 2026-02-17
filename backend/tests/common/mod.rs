use include_dir::{Dir, include_dir};
use log::{debug, error};
use rusqlite::Connection;
use rusqlite_migration::Migrations;
use std::result::Result;
use std::sync::LazyLock;
use tokio::sync::Mutex;

use crate::settings;

static TEST_MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/tests/database_migrations");

// Define migrations. These are applied atomically.
static TEST_MIGRATIONS: LazyLock<Migrations<'static>> =
    LazyLock::new(|| Migrations::from_directory(&TEST_MIGRATIONS_DIR).unwrap());

static INITIALISED: Mutex<bool> = Mutex::const_new(false);

pub async fn setup_database() {
    let mut initialised = INITIALISED.lock().await;
    if *initialised {
        return;
    }

    let conn = db::init_db().unwrap();
    TEST_MIGRATIONS.to_latest(&mut conn).unwrap();

    *initialised = true;
}
