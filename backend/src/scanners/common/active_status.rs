use crate::model::devices::Device;
use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use std::collections::HashSet;
use std::sync::Mutex;

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

    /// Record the result of a completed scan. A single scan can surface the same device more than
    /// once — duplicate ARP replies, or one MAC bound to several IPs in an SNMP ARP cache — so the
    /// reported count is the number of distinct devices (by MAC address), not raw sightings.
    pub fn record_scan(&mut self, devices: &[Device]) {
        let distinct = devices
            .iter()
            .map(|device| &device.mac_address)
            .collect::<HashSet<_>>()
            .len();
        self.last_scan_devices_seen = Some(distinct as u64);
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

/// A lazily-initialised, mutex-guarded [`ActiveStatus`] owned by a single active scanner. Each
/// scanner declares one as a `static` and the API layer reads it back via [`get`](Self::get).
/// All methods are no-ops until [`init`](Self::init) is called (mirroring the previous
/// per-scanner `OnceCell` behaviour).
pub struct ActiveStatusCell(OnceCell<Mutex<ActiveStatus>>);

impl ActiveStatusCell {
    pub const fn new() -> Self {
        Self(OnceCell::new())
    }

    pub fn init(&self) {
        self.0.set(Mutex::new(ActiveStatus::new())).ok();
    }

    pub fn set_running(&self) {
        if let Some(m) = self.0.get() {
            m.lock().unwrap().set_running();
        }
    }

    pub fn set_waiting(&self, next_scan_at: DateTime<Utc>) {
        if let Some(m) = self.0.get() {
            m.lock().unwrap().set_waiting(next_scan_at);
        }
    }

    pub fn record_scan(&self, devices: &[Device]) {
        if let Some(m) = self.0.get() {
            m.lock().unwrap().record_scan(devices);
        }
    }

    pub fn get(&self) -> Option<ActiveSnapshot> {
        self.0.get().map(|m| m.lock().unwrap().snapshot())
    }
}

impl Default for ActiveStatusCell {
    fn default() -> Self {
        Self::new()
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

    fn device_with_mac(mac: &str, ip: &str) -> Device {
        Device::new(mac.to_string(), ip.to_string(), String::new(), Utc::now())
    }

    #[test]
    fn record_scan_stores_count_and_time() {
        let mut status = ActiveStatus::new();
        let devices = vec![
            device_with_mac("aa:bb:cc:dd:ee:01", "192.168.0.2"),
            device_with_mac("aa:bb:cc:dd:ee:02", "192.168.0.3"),
        ];
        status.record_scan(&devices);
        let snapshot = status.snapshot();
        assert_eq!(snapshot.last_scan_devices_seen, Some(2));
        assert!(snapshot.last_scan_at.is_some());
    }

    #[test]
    fn record_scan_counts_distinct_devices() {
        let mut status = ActiveStatus::new();
        // Same MAC seen twice (e.g. duplicate ARP reply or one MAC on two IPs) plus a second
        // distinct device — only two unique devices should be reported.
        let devices = vec![
            device_with_mac("aa:bb:cc:dd:ee:01", "192.168.0.2"),
            device_with_mac("aa:bb:cc:dd:ee:01", "192.168.0.9"),
            device_with_mac("aa:bb:cc:dd:ee:02", "192.168.0.3"),
        ];
        status.record_scan(&devices);
        assert_eq!(status.snapshot().last_scan_devices_seen, Some(2));
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
