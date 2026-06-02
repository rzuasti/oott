use chrono::{DateTime, Duration, Utc};
use once_cell::sync::OnceCell;
use std::collections::HashMap;
use std::sync::Mutex;

/// A device counts as "seen" only if its most recent sighting falls within this
/// rolling window.
const RECENT_WINDOW_SECONDS: i64 = 3600;

pub struct DhcpScannerStatus {
    pub is_listening: bool,
    pub listening_since: Option<DateTime<Utc>>,
    /// Most recent sighting time per device MAC, used to count the distinct
    /// devices seen within the last hour.
    pub recent_sightings: HashMap<String, DateTime<Utc>>,
    pub last_discovery_at: Option<DateTime<Utc>>,
}

#[derive(Clone)]
pub struct DhcpScannerStatusSnapshot {
    pub is_listening: bool,
    pub listening_since: Option<DateTime<Utc>>,
    /// Distinct devices seen within the last hour.
    pub devices_last_hour: u64,
    pub last_discovery_at: Option<DateTime<Utc>>,
}

static STATUS: OnceCell<Mutex<DhcpScannerStatus>> = OnceCell::new();

pub fn init() {
    STATUS
        .set(Mutex::new(DhcpScannerStatus {
            is_listening: false,
            listening_since: None,
            recent_sightings: HashMap::new(),
            last_discovery_at: None,
        }))
        .ok();
}

pub fn set_listening() {
    if let Some(m) = STATUS.get() {
        let mut s = m.lock().unwrap();
        s.is_listening = true;
        s.listening_since = Some(Utc::now());
    }
}

pub fn record_discovery(mac: &str) {
    if let Some(m) = STATUS.get() {
        let now = Utc::now();
        let mut s = m.lock().unwrap();
        s.recent_sightings.insert(mac.to_string(), now);
        s.last_discovery_at = Some(now);
    }
}

pub fn get() -> Option<DhcpScannerStatusSnapshot> {
    STATUS.get().map(|m| {
        let mut s = m.lock().unwrap();
        let cutoff = Utc::now() - Duration::seconds(RECENT_WINDOW_SECONDS);
        s.recent_sightings.retain(|_, seen| *seen >= cutoff);
        DhcpScannerStatusSnapshot {
            is_listening: s.is_listening,
            listening_since: s.listening_since,
            devices_last_hour: s.recent_sightings.len() as u64,
            last_discovery_at: s.last_discovery_at,
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn reset_for_test() {
        if let Some(m) = STATUS.get() {
            let mut s = m.lock().unwrap();
            s.is_listening = false;
            s.listening_since = None;
            s.recent_sightings.clear();
            s.last_discovery_at = None;
        } else {
            init();
        }
    }

    #[test]
    fn test_set_listening() {
        reset_for_test();
        set_listening();
        let snapshot = get().unwrap();
        assert!(snapshot.is_listening);
        assert!(snapshot.listening_since.is_some());
    }

    #[test]
    fn test_same_mac_counts_once() {
        reset_for_test();
        record_discovery("aa:bb:cc:dd:ee:ff");
        record_discovery("aa:bb:cc:dd:ee:ff");
        let snapshot = get().unwrap();
        assert_eq!(snapshot.devices_last_hour, 1);
        assert!(snapshot.last_discovery_at.is_some());
    }

    #[test]
    fn test_distinct_macs_counted() {
        reset_for_test();
        record_discovery("aa:bb:cc:dd:ee:ff");
        record_discovery("11:22:33:44:55:66");
        let snapshot = get().unwrap();
        assert_eq!(snapshot.devices_last_hour, 2);
    }

    #[test]
    fn test_old_sighting_excluded() {
        reset_for_test();
        record_discovery("aa:bb:cc:dd:ee:ff");
        // Backdate an entry beyond the window; it must not be counted.
        if let Some(m) = STATUS.get() {
            let mut s = m.lock().unwrap();
            s.recent_sightings.insert(
                "11:22:33:44:55:66".to_string(),
                Utc::now() - Duration::seconds(RECENT_WINDOW_SECONDS + 60),
            );
        }
        let snapshot = get().unwrap();
        assert_eq!(snapshot.devices_last_hour, 1);
    }

    #[test]
    fn test_initial_state() {
        reset_for_test();
        let snapshot = get().unwrap();
        assert!(!snapshot.is_listening);
        assert!(snapshot.listening_since.is_none());
        assert_eq!(snapshot.devices_last_hour, 0);
        assert!(snapshot.last_discovery_at.is_none());
    }
}
