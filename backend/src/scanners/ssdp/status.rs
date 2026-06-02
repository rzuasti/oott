use once_cell::sync::OnceCell;
use std::sync::Mutex;

use crate::scanners::common::passive_status::{PassiveSnapshot, PassiveStatus};

static STATUS: OnceCell<Mutex<PassiveStatus>> = OnceCell::new();

pub fn init() {
    STATUS.set(Mutex::new(PassiveStatus::new())).ok();
}

pub fn set_listening() {
    if let Some(m) = STATUS.get() {
        m.lock().unwrap().set_listening();
    }
}

pub fn record_discovery(mac: &str) {
    if let Some(m) = STATUS.get() {
        m.lock().unwrap().record_discovery(mac);
    }
}

pub fn get() -> Option<PassiveSnapshot> {
    STATUS.get().map(|m| m.lock().unwrap().snapshot())
}
