use chrono::Utc;
use log::{debug, error};
use rusqlite::params;

use crate::db;
use crate::db::error::DbError;
use crate::model::push_tokens::{PushPlatform, PushToken};

// Register a token or refresh an existing one. A token is unique, so re-registering the same token
// (e.g. on app launch or after an FCM token refresh) updates its platform and `last_seen` rather
// than inserting a duplicate. `created_on` is preserved on update so it keeps recording first sight.
pub fn upsert(token: &str, platform: PushPlatform) -> Result<(), DbError> {
    let conn = db::get_db_connection()?;
    let now = Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Nanos, false);

    match conn.execute(
        "INSERT INTO push_tokens (token, platform, created_on, last_seen) VALUES (?1, ?2, ?3, ?3)
         ON CONFLICT(token) DO UPDATE SET platform = excluded.platform, last_seen = excluded.last_seen",
        params![token, platform, now],
    ) {
        Ok(_) => {
            debug!("Push token upserted (platform={platform})");
            Ok(())
        }
        Err(error) => {
            error!("Error upserting push token into database: {error}");
            Err(DbError::from(error))
        }
    }
}

pub fn list() -> Result<Vec<PushToken>, DbError> {
    debug!("Listing push tokens");
    let conn = db::get_db_connection()?;

    let mut stmt = conn.prepare(
        "SELECT id, token, platform, created_on, last_seen FROM push_tokens ORDER BY id",
    )?;

    let tokens: Vec<PushToken> = stmt
        .query_map([], |row| {
            Ok(PushToken {
                id: row.get(0)?,
                token: row.get(1)?,
                platform: row.get(2)?,
                created_on: row.get(3)?,
                last_seen: row.get(4)?,
            })
        })?
        .collect::<Result<_, _>>()?;

    Ok(tokens)
}

pub fn delete(token: &str) -> Result<usize, DbError> {
    let conn = db::get_db_connection()?;

    match conn.execute("DELETE FROM push_tokens WHERE token = ?1", params![token]) {
        Ok(count) => {
            debug!("Deleted {count} push token(s)");
            Ok(count)
        }
        Err(error) => {
            error!("Error deleting push token from database: {error}");
            Err(DbError::from(error))
        }
    }
}

// Prune a batch of dead tokens reported by the relay (those FCM rejected as unregistered/invalid),
// so the table does not accumulate tokens that can never be delivered to again. Deleting one at a
// time keeps the call simple and the batches are small (one delivery's worth of tokens).
pub fn delete_many(tokens: &[String]) -> Result<usize, DbError> {
    if tokens.is_empty() {
        return Ok(0);
    }

    let mut conn = db::get_db_connection()?;
    let tx = conn.transaction()?;
    let mut deleted = 0;
    {
        let mut stmt = tx.prepare("DELETE FROM push_tokens WHERE token = ?1")?;
        for token in tokens {
            deleted += stmt.execute(params![token])?;
        }
    }
    tx.commit()?;

    debug!("Pruned {deleted} dead push token(s)");
    Ok(deleted)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    // Count how many of the given tokens are currently stored. Scoped to the test's own tokens
    // because the test database is shared across tests.
    fn stored(tokens: &[&str]) -> usize {
        let all = list().unwrap();
        tokens
            .iter()
            .filter(|t| all.iter().any(|stored| &stored.token == *t))
            .count()
    }

    #[tokio::test]
    async fn upsert_inserts_then_updates_without_duplicating() {
        tests_common::setup().await;

        let token = "push-token-upsert-1";
        upsert(token, PushPlatform::Android).unwrap();

        let after_insert = list().unwrap();
        let row = after_insert.iter().find(|t| t.token == token).unwrap();
        assert_eq!(row.platform, PushPlatform::Android);
        let created_on = row.created_on;
        let count_after_insert = after_insert.iter().filter(|t| t.token == token).count();
        assert_eq!(count_after_insert, 1);

        // Re-registering the same token updates platform/last_seen and never duplicates the row.
        upsert(token, PushPlatform::Ios).unwrap();
        let after_update = list().unwrap();
        let rows: Vec<_> = after_update.iter().filter(|t| t.token == token).collect();
        assert_eq!(rows.len(), 1, "Re-registering must not create a second row");
        assert_eq!(
            rows[0].platform,
            PushPlatform::Ios,
            "Platform should update"
        );
        assert_eq!(
            rows[0].created_on, created_on,
            "created_on must be preserved across an upsert"
        );
    }

    #[tokio::test]
    async fn delete_removes_a_token() {
        tests_common::setup().await;

        let token = "push-token-delete-1";
        upsert(token, PushPlatform::Android).unwrap();
        assert_eq!(stored(&[token]), 1);

        let deleted = delete(token).unwrap();
        assert_eq!(deleted, 1);
        assert_eq!(stored(&[token]), 0);

        // Deleting an absent token is a no-op, not an error.
        assert_eq!(delete(token).unwrap(), 0);
    }

    #[tokio::test]
    async fn delete_many_prunes_only_the_listed_tokens() {
        tests_common::setup().await;

        let dead_a = "push-token-prune-dead-a";
        let dead_b = "push-token-prune-dead-b";
        let live = "push-token-prune-live";
        upsert(dead_a, PushPlatform::Android).unwrap();
        upsert(dead_b, PushPlatform::Ios).unwrap();
        upsert(live, PushPlatform::Android).unwrap();

        let pruned = delete_many(&[dead_a.to_string(), dead_b.to_string()]).unwrap();
        assert_eq!(pruned, 2);
        assert_eq!(stored(&[dead_a, dead_b]), 0, "Dead tokens should be pruned");
        assert_eq!(stored(&[live]), 1, "Live token must remain");

        // An empty prune list is a no-op.
        assert_eq!(delete_many(&[]).unwrap(), 0);
    }
}
