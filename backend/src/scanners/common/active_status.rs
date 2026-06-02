use chrono::{DateTime, Utc};

/// Status state for the active (polling) scanners — ARP and SNMP. Each scanner owns its own
/// `OnceCell<Mutex<ActiveStatus>>` and delegates to these methods (see e.g.
/// [`crate::scanners::arp::status`]).
#[derive(Default)]
pub struct ActiveStatus {
    is_running: bool,
    scan_started_at: Option<DateTime<Utc>>,
    next_scan_at: Option<DateTime<Utc>>,
    last_scan_devices_seen: Option<u64>,
    last_scan_at: Option<DateTime<Utc>>,
}

/// A point-in-time copy of an [`ActiveStatus`], handed to the API layer.
#[derive(Clone)]
pub struct ActiveSnapshot {
    pub is_running: bool,
    pub scan_started_at: Option<DateTime<Utc>>,
    pub next_scan_at: Option<DateTime<Utc>>,
    pub last_scan_devices_seen: Option<u64>,
    pub last_scan_at: Option<DateTime<Utc>>,
}

impl ActiveStatus {
    pub fn new() -> Self {
        Self::default()
    }

    /// Mark a scan as in progress.
    pub fn set_running(&mut self) {
        self.is_running = true;
        self.scan_started_at = Some(Utc::now());
        self.next_scan_at = None;
    }

    /// Mark the scanner as idle until `next_scan_at`.
    pub fn set_waiting(&mut self, next_scan_at: DateTime<Utc>) {
        self.is_running = false;
        self.scan_started_at = None;
        self.next_scan_at = Some(next_scan_at);
    }

    /// Record the result of a completed scan.
    pub fn record_scan(&mut self, devices_seen: u64) {
        self.last_scan_devices_seen = Some(devices_seen);
        self.last_scan_at = Some(Utc::now());
    }

    pub fn snapshot(&self) -> ActiveSnapshot {
        ActiveSnapshot {
            is_running: self.is_running,
            scan_started_at: self.scan_started_at,
            next_scan_at: self.next_scan_at,
            last_scan_devices_seen: self.last_scan_devices_seen,
            last_scan_at: self.last_scan_at,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_running_marks_in_progress() {
        let mut status = ActiveStatus::new();
        status.set_running();
        let snapshot = status.snapshot();
        assert!(snapshot.is_running);
        assert!(snapshot.scan_started_at.is_some());
        assert!(snapshot.next_scan_at.is_none());
    }

    #[test]
    fn set_waiting_records_next_scan() {
        let mut status = ActiveStatus::new();
        let next = Utc::now() + chrono::Duration::seconds(60);
        status.set_waiting(next);
        let snapshot = status.snapshot();
        assert!(!snapshot.is_running);
        assert!(snapshot.scan_started_at.is_none());
        assert_eq!(snapshot.next_scan_at.unwrap(), next);
    }

    #[test]
    fn record_scan_stores_count_and_time() {
        let mut status = ActiveStatus::new();
        status.record_scan(7);
        let snapshot = status.snapshot();
        assert_eq!(snapshot.last_scan_devices_seen, Some(7));
        assert!(snapshot.last_scan_at.is_some());
    }

    #[test]
    fn initial_state_is_empty() {
        let snapshot = ActiveStatus::new().snapshot();
        assert!(!snapshot.is_running);
        assert!(snapshot.scan_started_at.is_none());
        assert!(snapshot.next_scan_at.is_none());
        assert!(snapshot.last_scan_devices_seen.is_none());
        assert!(snapshot.last_scan_at.is_none());
    }
}
