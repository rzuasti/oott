use std::collections::HashMap;
use std::sync::Mutex;

use chrono::{DateTime, Duration, Utc};
use once_cell::sync::OnceCell;

/// A device counts as "seen" only if its most recent sighting falls within this rolling window.
const RECENT_WINDOW_SECONDS: i64 = 3600;

/// Status state for the passive (listening) scanners — mDNS, SSDP and DHCP. Each scanner owns its
/// own `OnceCell<Mutex<PassiveStatus>>` and delegates to these methods (see e.g.
/// [`crate::scanners::mdns::status`]).
#[derive(Default)]
pub struct PassiveStatus {
    is_listening: bool,
    listening_since: Option<DateTime<Utc>>,
    /// Most recent sighting time per device MAC, used to count the distinct devices seen within
    /// the last hour.
    recent_sightings: HashMap<String, DateTime<Utc>>,
    last_discovery_at: Option<DateTime<Utc>>,
}

/// A point-in-time copy of a [`PassiveStatus`], handed to the API layer.
#[derive(Clone)]
pub struct PassiveSnapshot {
    pub is_listening: bool,
    pub listening_since: Option<DateTime<Utc>>,
    /// Distinct devices seen within the last hour.
    pub devices_last_hour: u64,
    pub last_discovery_at: Option<DateTime<Utc>>,
}

impl PassiveStatus {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_listening(&mut self) {
        self.is_listening = true;
        self.listening_since = Some(Utc::now());
    }

    pub fn record_discovery(&mut self, mac: &str) {
        let now = Utc::now();
        self.recent_sightings.insert(mac.to_string(), now);
        self.last_discovery_at = Some(now);
    }

    /// Snapshot the status, first pruning sightings older than the rolling window so the
    /// distinct-device count only reflects the last hour.
    pub fn snapshot(&mut self) -> PassiveSnapshot {
        let cutoff = Utc::now() - Duration::seconds(RECENT_WINDOW_SECONDS);
        self.recent_sightings.retain(|_, seen| *seen >= cutoff);
        PassiveSnapshot {
            is_listening: self.is_listening,
            listening_since: self.listening_since,
            devices_last_hour: self.recent_sightings.len() as u64,
            last_discovery_at: self.last_discovery_at,
        }
    }
}

/// A lazily-initialised, mutex-guarded [`PassiveStatus`] owned by a single passive scanner. Each
/// scanner declares one as a `static` and the API layer reads it back via [`get`](Self::get).
/// All methods are no-ops until [`init`](Self::init) is called (mirroring the previous
/// per-scanner `OnceCell` behaviour).
pub struct PassiveStatusCell(OnceCell<Mutex<PassiveStatus>>);

impl PassiveStatusCell {
    pub const fn new() -> Self {
        Self(OnceCell::new())
    }

    pub fn init(&self) {
        self.0.set(Mutex::new(PassiveStatus::new())).ok();
    }

    pub fn set_listening(&self) {
        if let Some(m) = self.0.get() {
            m.lock().unwrap().set_listening();
        }
    }

    pub fn record_discovery(&self, mac: &str) {
        if let Some(m) = self.0.get() {
            m.lock().unwrap().record_discovery(mac);
        }
    }

    pub fn get(&self) -> Option<PassiveSnapshot> {
        self.0.get().map(|m| m.lock().unwrap().snapshot())
    }
}

impl Default for PassiveStatusCell {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_listening_marks_active() {
        let mut status = PassiveStatus::new();
        status.set_listening();
        let snapshot = status.snapshot();
        assert!(snapshot.is_listening);
        assert!(snapshot.listening_since.is_some());
    }

    #[test]
    fn same_mac_counts_once() {
        let mut status = PassiveStatus::new();
        status.record_discovery("aa:bb:cc:dd:ee:ff");
        status.record_discovery("aa:bb:cc:dd:ee:ff");
        let snapshot = status.snapshot();
        assert_eq!(snapshot.devices_last_hour, 1);
        assert!(snapshot.last_discovery_at.is_some());
    }

    #[test]
    fn distinct_macs_counted() {
        let mut status = PassiveStatus::new();
        status.record_discovery("aa:bb:cc:dd:ee:ff");
        status.record_discovery("11:22:33:44:55:66");
        assert_eq!(status.snapshot().devices_last_hour, 2);
    }

    #[test]
    fn old_sighting_excluded() {
        let mut status = PassiveStatus::new();
        status.record_discovery("aa:bb:cc:dd:ee:ff");
        // Backdate an entry beyond the window; it must not be counted.
        status.recent_sightings.insert(
            "11:22:33:44:55:66".to_string(),
            Utc::now() - Duration::seconds(RECENT_WINDOW_SECONDS + 60),
        );
        assert_eq!(status.snapshot().devices_last_hour, 1);
    }

    #[test]
    fn initial_state_is_empty() {
        let snapshot = PassiveStatus::new().snapshot();
        assert!(!snapshot.is_listening);
        assert!(snapshot.listening_since.is_none());
        assert_eq!(snapshot.devices_last_hour, 0);
        assert!(snapshot.last_discovery_at.is_none());
    }
}
