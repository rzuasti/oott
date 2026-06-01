use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use std::sync::Mutex;

pub struct DhcpScannerStatus {
    pub is_listening: bool,
    pub listening_since: Option<DateTime<Utc>>,
    pub devices_discovered: u64,
    pub last_discovery_at: Option<DateTime<Utc>>,
}

#[derive(Clone)]
pub struct DhcpScannerStatusSnapshot {
    pub is_listening: bool,
    pub listening_since: Option<DateTime<Utc>>,
    pub devices_discovered: u64,
    pub last_discovery_at: Option<DateTime<Utc>>,
}

static STATUS: OnceCell<Mutex<DhcpScannerStatus>> = OnceCell::new();

pub fn init() {
    STATUS
        .set(Mutex::new(DhcpScannerStatus {
            is_listening: false,
            listening_since: None,
            devices_discovered: 0,
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

pub fn record_discovery() {
    if let Some(m) = STATUS.get() {
        let mut s = m.lock().unwrap();
        s.devices_discovered += 1;
        s.last_discovery_at = Some(Utc::now());
    }
}

pub fn get() -> Option<DhcpScannerStatusSnapshot> {
    STATUS.get().map(|m| {
        let s = m.lock().unwrap();
        DhcpScannerStatusSnapshot {
            is_listening: s.is_listening,
            listening_since: s.listening_since,
            devices_discovered: s.devices_discovered,
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
            s.devices_discovered = 0;
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
    fn test_record_discovery() {
        reset_for_test();
        record_discovery();
        record_discovery();
        let snapshot = get().unwrap();
        assert_eq!(snapshot.devices_discovered, 2);
        assert!(snapshot.last_discovery_at.is_some());
    }

    #[test]
    fn test_initial_state() {
        reset_for_test();
        let snapshot = get().unwrap();
        assert!(!snapshot.is_listening);
        assert!(snapshot.listening_since.is_none());
        assert_eq!(snapshot.devices_discovered, 0);
        assert!(snapshot.last_discovery_at.is_none());
    }
}
