use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use std::sync::Mutex;

pub struct ArpScannerStatus {
    pub is_running: bool,
    pub scan_started_at: Option<DateTime<Utc>>,
    pub next_scan_at: Option<DateTime<Utc>>,
}

#[derive(Clone)]
pub struct ArpScannerStatusSnapshot {
    pub is_running: bool,
    pub scan_started_at: Option<DateTime<Utc>>,
    pub next_scan_at: Option<DateTime<Utc>>,
}

static STATUS: OnceCell<Mutex<ArpScannerStatus>> = OnceCell::new();

pub fn init() {
    STATUS
        .set(Mutex::new(ArpScannerStatus {
            is_running: false,
            scan_started_at: None,
            next_scan_at: None,
        }))
        .ok();
}

pub fn set_running() {
    if let Some(m) = STATUS.get() {
        let mut s = m.lock().unwrap();
        s.is_running = true;
        s.scan_started_at = Some(Utc::now());
        s.next_scan_at = None;
    }
}

pub fn set_waiting(next_scan_at: DateTime<Utc>) {
    if let Some(m) = STATUS.get() {
        let mut s = m.lock().unwrap();
        s.is_running = false;
        s.scan_started_at = None;
        s.next_scan_at = Some(next_scan_at);
    }
}

pub fn get() -> Option<ArpScannerStatusSnapshot> {
    STATUS.get().map(|m| {
        let s = m.lock().unwrap();
        ArpScannerStatusSnapshot {
            is_running: s.is_running,
            scan_started_at: s.scan_started_at,
            next_scan_at: s.next_scan_at,
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn reset_for_test() {
        if let Some(m) = STATUS.get() {
            let mut s = m.lock().unwrap();
            s.is_running = false;
            s.scan_started_at = None;
            s.next_scan_at = None;
        } else {
            init();
        }
    }

    #[test]
    fn test_set_running() {
        reset_for_test();
        set_running();
        let snapshot = get().unwrap();
        assert!(snapshot.is_running);
        assert!(snapshot.scan_started_at.is_some());
        assert!(snapshot.next_scan_at.is_none());
    }

    #[test]
    fn test_set_waiting() {
        reset_for_test();
        let next = Utc::now() + chrono::Duration::seconds(60);
        set_waiting(next);
        let snapshot = get().unwrap();
        assert!(!snapshot.is_running);
        assert!(snapshot.scan_started_at.is_none());
        assert_eq!(snapshot.next_scan_at.unwrap(), next);
    }

    #[test]
    fn test_initial_state() {
        reset_for_test();
        let snapshot = get().unwrap();
        assert!(!snapshot.is_running);
        assert!(snapshot.scan_started_at.is_none());
        assert!(snapshot.next_scan_at.is_none());
    }
}
