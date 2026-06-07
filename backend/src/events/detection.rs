use std::time::Duration;

use chrono::Local;

use crate::model::device_events::DeviceChange;
use crate::model::devices::Device;
use crate::settings::get_settings;

// Whether a re-sighting represents a real vendor change. A scanner that cannot deduce a vendor
// reports an empty string; that is not a change (db::devices::seen keeps the known vendor), so
// it must not raise a "vendor changed" notification either. Likewise, first deducing a vendor for a
// device that previously had none is not a change worth notifying about.
pub fn vendor_changed(existing: &str, new: &str) -> bool {
    !existing.is_empty() && !new.is_empty() && existing != new
}

// Whether a re-sighting represents a real IP-address change, mirroring vendor_changed. First
// learning an address for a device that previously had none (empty -> value, e.g. a device known
// only from a DHCP DISCOVER that later gets an ARP address) is not a change worth recording or
// notifying about. A sighting that carries no address (value -> empty) is likewise not a change;
// the pipeline already backfills the stored address in that case, so an empty `new` never reaches
// here, but the guard keeps this correct independently of the caller.
pub fn ip_changed(existing: &str, new: &str) -> bool {
    !existing.is_empty() && !new.is_empty() && existing != new
}

/// Decide what notification-worthy changes a known device's re-sighting represents, comparing the
/// stored record against the freshly seen one. A return after the configured absence is a
/// "back online" change; an IP and/or vendor difference is a "changed" change (both can occur for
/// the same sighting). The absence threshold and current time are read from settings here; this
/// function performs no database writes and raises no notifications, so the recording layer stays
/// in full control of side effects.
pub fn detect_known_device_changes(existing: &Device, new: &Device) -> Vec<DeviceChange> {
    let mut changes = Vec::new();

    let elapsed_since_last_seen: Duration = (Local::now().to_utc() - existing.last_seen)
        .to_std()
        .unwrap_or(Duration::from_secs(0));
    if elapsed_since_last_seen
        >= Duration::from(get_settings().notifications.notify_when_not_seen_for)
    {
        changes.push(DeviceChange::BackOnline {
            device: new.clone(),
            absent_for: elapsed_since_last_seen,
        });
    }

    let ip_changed_flag = ip_changed(&existing.ipv4_address, &new.ipv4_address);
    let vendor_changed_flag = vendor_changed(&existing.vendor, &new.vendor);
    if ip_changed_flag || vendor_changed_flag {
        changes.push(DeviceChange::Changed {
            existing: existing.clone(),
            new: new.clone(),
            ip_changed: ip_changed_flag,
            vendor_changed: vendor_changed_flag,
        });
    }

    changes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_new_vendor_is_not_a_change() {
        assert!(!vendor_changed("Apple, Inc.", ""));
    }

    #[test]
    fn different_non_empty_vendor_is_a_change() {
        assert!(vendor_changed("Apple, Inc.", "Google, Inc."));
    }

    #[test]
    fn same_vendor_is_not_a_change() {
        assert!(!vendor_changed("Apple, Inc.", "Apple, Inc."));
    }

    #[test]
    fn newly_deduced_vendor_from_empty_is_not_a_change() {
        assert!(!vendor_changed("", "Apple, Inc."));
    }

    #[test]
    fn first_ip_from_empty_is_not_a_change() {
        // A device that gains its first address (empty -> value) has not "changed" its IP.
        assert!(!ip_changed("", "192.168.1.42"));
    }

    #[test]
    fn ip_to_empty_is_not_a_change() {
        assert!(!ip_changed("192.168.1.42", ""));
    }

    #[test]
    fn different_non_empty_ip_is_a_change() {
        assert!(ip_changed("192.168.1.42", "192.168.1.99"));
    }

    #[test]
    fn same_ip_is_not_a_change() {
        assert!(!ip_changed("192.168.1.42", "192.168.1.42"));
    }
}
