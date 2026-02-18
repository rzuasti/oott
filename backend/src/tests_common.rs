use crate::db;
use include_dir::{Dir, include_dir};
use rusqlite_migration::Migrations;
use std::sync::LazyLock;
use tokio::sync::Mutex;

static TEST_MIGRATIONS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/tests_database_migrations");

// Define migrations. These are applied atomically.
static TEST_MIGRATIONS: LazyLock<Migrations<'static>> =
    LazyLock::new(|| Migrations::from_directory(&TEST_MIGRATIONS_DIR).unwrap());

static INITIALISED: Mutex<bool> = Mutex::const_new(false);

pub async fn setup_database() {
    let mut initialised = INITIALISED.lock().await;
    if *initialised {
        return;
    }
    db::init_db().await.unwrap();
    let mut conn = db::get_db_connection();
    TEST_MIGRATIONS.to_latest(&mut conn).unwrap();

    *initialised = true;
}
