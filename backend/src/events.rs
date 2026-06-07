mod detection;

use std::time::Duration;

use chrono::Utc;
use log::{debug, error};

use crate::db;
use crate::model::device_events::{DeviceChange, DeviceEvent, DeviceEventScanner, DeviceEventType};
use crate::model::devices::Device;
use crate::settings::get_settings;

// Build a device event describing this sighting of `device`. The event carries the sighting's MAC,
// IPv4 and vendor so the event history reflects what was actually seen.
fn device_event(
    device: &Device,
    event_type: DeviceEventType,
    scanner: DeviceEventScanner,
) -> DeviceEvent {
    DeviceEvent::new(
        device.mac_address.clone(),
        Utc::now(),
        event_type,
        device.ipv4_address.clone(),
        device.vendor.clone(),
        scanner,
    )
}

// The device event type recorded for a detected change.
fn event_type_for(change: &DeviceChange) -> DeviceEventType {
    match change {
        DeviceChange::New(_) => DeviceEventType::NewDevice,
        DeviceChange::BackOnline { .. } => DeviceEventType::DeviceBackOnline,
        DeviceChange::Changed { .. } => DeviceEventType::DeviceChanged,
    }
}

/// Record a device event, skipping it when the same scanner already recorded an event for the
/// same device (same MAC and IPv4) within the configured deduplication window. This keeps the
/// events table from filling with near-identical rows when a scanner sees a device repeatedly.
///
/// Returns `true` when the event was recorded and `false` when it was suppressed as a duplicate, so
/// callers can apply the same deduplication window to the notification the sighting would raise (and
/// therefore to its persistence and channel delivery), not just to the device_events table.
fn record_event(event: DeviceEvent) -> bool {
    let window: Duration = get_settings().device_events.deduplication_window.into();
    let since = Utc::now() - chrono::Duration::from_std(window).unwrap_or_default();

    match db::device_events::recent_duplicate_exists(
        &event.mac_address,
        &event.scanner,
        &event.event_type,
        since,
    ) {
        Ok(true) => {
            debug!("Skipping duplicate device event within window: {event}");
            return false;
        }
        Ok(false) => {}
        // On a check error, fall through and record the event rather than silently drop it.
        Err(err) => error!("Device event deduplication check failed ({err}); recording event"),
    }

    if let Err(err) = db::device_events::insert(event) {
        error!("Failed to record device event: {err}");
    }
    true
}

/// Record the device event for a brand-new device and return the change to notify about, or `None`
/// when the sighting is deduplicated within the configured window (so the same window suppresses the
/// notification as well as the device event). Sending is left to the `notifications` module so an
/// active scan can consolidate many new devices into one notification.
pub fn record_new_device(device: Device, scanner: DeviceEventScanner) -> Option<DeviceChange> {
    if !record_event(device_event(&device, DeviceEventType::NewDevice, scanner)) {
        return None;
    }
    Some(DeviceChange::New(device))
}

/// Record the device events for a known device's re-sighting and return the notification-worthy
/// changes (it may return both a "back online" and a "changed" entry, or none). Every sighting
/// records a baseline `DeviceSeen` event (the history heartbeat, no notification); detection decides
/// the candidate changes and each one's own event type is recorded here. Each event type is
/// deduplicated independently within the configured window, so a recent routine sighting never
/// suppresses a genuine change or return, and a change is returned only once its event is actually
/// recorded (the window therefore gates the notification too). Sending is left to `notifications`.
pub fn record_known_device(
    existing: Device,
    new: Device,
    scanner: DeviceEventScanner,
) -> Vec<DeviceChange> {
    // Baseline presence heartbeat for the event history. Recorded (subject to its own dedup) for
    // every sighting and never raises a notification.
    record_event(device_event(
        &new,
        DeviceEventType::DeviceSeen,
        scanner.clone(),
    ));

    detection::detect_known_device_changes(&existing, &new)
        .into_iter()
        .filter(|change| record_event(device_event(&new, event_type_for(change), scanner.clone())))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::notifications::NotificationType;
    use crate::notifications;
    use chrono::TimeZone;

    fn sample_device(name: Option<&str>) -> Device {
        let mut device = Device::new(
            "aa:bb:cc:dd:ee:ff".to_string(),
            "192.168.1.42".to_string(),
            "Apple, Inc.".to_string(),
            Utc.with_ymd_and_hms(2026, 6, 1, 12, 0, 0).unwrap(),
        );
        device.name = name.map(str::to_string);
        device.device_type = "Smartphone".to_string();
        device
    }

    // Count recorded events of a given type for a device. Scoped per-MAC because the test DB is
    // shared across tests.
    fn event_count(mac: &str, event_type: DeviceEventType) -> usize {
        db::device_events::list(Some(mac.to_string()), None, None, None)
            .unwrap()
            .into_iter()
            .filter(|event| event.event_type == event_type)
            .count()
    }

    #[tokio::test]
    async fn repeated_sighting_from_same_scanner_records_one_event() {
        crate::tests_common::setup().await;

        let mut device = Device::new(
            "fa:ce:fa:ce:00:01".to_string(),
            "192.168.7.7".to_string(),
            "Acme".to_string(),
            Utc::now(),
        );
        device.last_seen = Utc::now();
        let mac = device.mac_address.clone();

        // Two sightings from the same scanner within the dedup window: only one event recorded.
        record_known_device(device.clone(), device.clone(), DeviceEventScanner::Arp);
        record_known_device(device.clone(), device.clone(), DeviceEventScanner::Arp);

        let after_arp = db::device_events::list(Some(mac.clone()), None, None, None).unwrap();
        assert_eq!(
            after_arp.len(),
            1,
            "A repeated same-scanner sighting should be deduplicated"
        );

        // A sighting from a different scanner is not a duplicate and is recorded.
        record_known_device(device.clone(), device.clone(), DeviceEventScanner::Mdns);

        let after_mdns = db::device_events::list(Some(mac), None, None, None).unwrap();
        assert_eq!(
            after_mdns.len(),
            2,
            "A sighting from a different scanner should be recorded"
        );
    }

    #[tokio::test]
    async fn deduplicated_sighting_raises_no_second_notification() {
        crate::tests_common::setup().await;

        // A known device absent long enough that every sighting would, on its own, raise a
        // "back online" notification.
        let mut existing = sample_device(Some("dedup-back-online"));
        existing.mac_address = "fa:ce:fa:ce:03:01".to_string();
        existing.last_seen = Utc::now() - chrono::Duration::days(30);
        let new = existing.clone();

        let back_online_notifications = || {
            db::notifications::list(None, None, None)
                .unwrap()
                .into_iter()
                .filter(|n| {
                    n.notification_type == NotificationType::DeviceOnlineAfterTime
                        && n.body.contains("dedup-back-online")
                })
                .count()
        };

        // First sighting records the event and persists the notification.
        notifications::notify(record_known_device(
            existing.clone(),
            new.clone(),
            DeviceEventScanner::Arp,
        ));
        assert_eq!(
            back_online_notifications(),
            1,
            "The first sighting should persist a back-online notification"
        );

        // A second sighting from the same scanner within the dedup window is suppressed, so it must
        // neither persist a notification nor (had the delivery loop been running) deliver one.
        notifications::notify(record_known_device(
            existing.clone(),
            new.clone(),
            DeviceEventScanner::Arp,
        ));
        assert_eq!(
            back_online_notifications(),
            1,
            "A deduplicated sighting must not persist a second notification"
        );
    }

    #[tokio::test]
    async fn first_ip_assignment_raises_no_changed_notification() {
        crate::tests_common::setup().await;

        // A known device that had no address yet (e.g. discovered from a DHCP DISCOVER) is now seen
        // with a real one. Gaining a first IP is not a change, so no "changed" notification is due.
        let mut existing = sample_device(Some("dhcp-only-device"));
        existing.mac_address = "fa:ce:fa:ce:04:01".to_string();
        existing.ipv4_address = String::new();
        existing.last_seen = Utc::now();

        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.77".to_string();

        let changes = record_known_device(existing, new, DeviceEventScanner::Arp);

        assert!(
            !changes
                .iter()
                .any(|change| matches!(change, DeviceChange::Changed { .. })),
            "Filling a previously empty IP must not be classified as a change"
        );
    }

    #[tokio::test]
    async fn changed_sighting_records_a_changed_event_and_notification() {
        crate::tests_common::setup().await;

        // A known device, recently seen (so not "back online"), now reports a different IP.
        let mut existing = sample_device(Some("changed-device"));
        existing.mac_address = "fa:ce:fa:ce:05:01".to_string();
        existing.last_seen = Utc::now();
        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.123".to_string();
        let mac = existing.mac_address.clone();

        notifications::notify(record_known_device(existing, new, DeviceEventScanner::Arp));

        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceSeen),
            1,
            "Every sighting records a baseline DeviceSeen event"
        );
        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceChanged),
            1,
            "A changed sighting additionally records a DeviceChanged event"
        );
        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceBackOnline),
            0,
            "A recently-seen device is not back online"
        );

        let changed_notifications = db::notifications::list(None, None, None)
            .unwrap()
            .into_iter()
            .filter(|n| {
                n.notification_type == NotificationType::DeviceChanged
                    && n.mac_address.as_deref() == Some(mac.as_str())
            })
            .count();
        assert_eq!(
            changed_notifications, 1,
            "A changed sighting raises a DeviceChanged notification"
        );
    }

    #[tokio::test]
    async fn back_online_sighting_records_a_back_online_event_and_notification() {
        crate::tests_common::setup().await;

        // A known device, unchanged, absent long enough to be "back online".
        let mut existing = sample_device(Some("back-online-device"));
        existing.mac_address = "fa:ce:fa:ce:05:02".to_string();
        existing.last_seen = Utc::now() - chrono::Duration::days(30);
        let new = existing.clone();
        let mac = existing.mac_address.clone();

        notifications::notify(record_known_device(existing, new, DeviceEventScanner::Arp));

        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceSeen),
            1,
            "Every sighting records a baseline DeviceSeen event"
        );
        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceBackOnline),
            1,
            "A return after the absence threshold records a DeviceBackOnline event"
        );
        assert_eq!(
            event_count(&mac, DeviceEventType::DeviceChanged),
            0,
            "An unchanged device records no DeviceChanged event"
        );

        let back_online_notifications = db::notifications::list(None, None, None)
            .unwrap()
            .into_iter()
            .filter(|n| {
                n.notification_type == NotificationType::DeviceOnlineAfterTime
                    && n.mac_address.as_deref() == Some(mac.as_str())
            })
            .count();
        assert_eq!(
            back_online_notifications, 1,
            "A back-online sighting raises a DeviceOnlineAfterTime notification"
        );
    }

    #[tokio::test]
    async fn changed_and_back_online_sighting_records_three_events_and_two_notifications() {
        crate::tests_common::setup().await;

        // A known device that is both absent long enough and reports a different IP on its return.
        let mut existing = sample_device(Some("changed-and-back-device"));
        existing.mac_address = "fa:ce:fa:ce:05:03".to_string();
        existing.last_seen = Utc::now() - chrono::Duration::days(30);
        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.200".to_string();
        let mac = existing.mac_address.clone();

        notifications::notify(record_known_device(existing, new, DeviceEventScanner::Arp));

        assert_eq!(event_count(&mac, DeviceEventType::DeviceSeen), 1);
        assert_eq!(event_count(&mac, DeviceEventType::DeviceChanged), 1);
        assert_eq!(event_count(&mac, DeviceEventType::DeviceBackOnline), 1);

        let notifications: Vec<_> = db::notifications::list(None, None, None)
            .unwrap()
            .into_iter()
            .filter(|n| n.mac_address.as_deref() == Some(mac.as_str()))
            .collect();
        assert_eq!(
            notifications.len(),
            2,
            "A changed-and-back-online sighting raises exactly two notifications"
        );
        assert!(
            notifications
                .iter()
                .any(|n| n.notification_type == NotificationType::DeviceChanged)
        );
        assert!(
            notifications
                .iter()
                .any(|n| n.notification_type == NotificationType::DeviceOnlineAfterTime)
        );
    }
}
