use chrono::{DateTime, Utc};
use once_cell::sync::OnceCell;
use std::sync::Mutex;

use crate::model::devices::Device;
use crate::scanners::common::active_status::{ActiveSnapshot, ActiveStatus};

static STATUS: OnceCell<Mutex<ActiveStatus>> = OnceCell::new();

pub fn init() {
    STATUS.set(Mutex::new(ActiveStatus::new())).ok();
}

pub fn set_running() {
    if let Some(m) = STATUS.get() {
        m.lock().unwrap().set_running();
    }
}

pub fn set_waiting(next_scan_at: DateTime<Utc>) {
    if let Some(m) = STATUS.get() {
        m.lock().unwrap().set_waiting(next_scan_at);
    }
}

pub fn record_scan(devices: &[Device]) {
    if let Some(m) = STATUS.get() {
        m.lock().unwrap().record_scan(devices);
    }
}

pub fn get() -> Option<ActiveSnapshot> {
    STATUS.get().map(|m| m.lock().unwrap().snapshot())
}
