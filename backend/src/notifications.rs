mod delivery;
mod error;
mod push;
mod pushover;
mod render;

use std::time::Duration;

use chrono::Utc;
use log::{debug, error};

use crate::db;
use crate::model::device_events::DeviceChange;
use crate::model::devices::Device;
use crate::model::notifications::{Notification, NotificationType};

pub use delivery::run_delivery;

/// Send notifications for the changes detected during a scan (or a single sighting). Changes are
/// grouped by notification type: a type with exactly one change produces the usual single-device
/// notification (carrying its MAC), while a type with two or more produces one consolidated summary
/// with an empty MAC. Each notification is persisted and handed to the delivery task.
pub fn notify(changes: Vec<DeviceChange>) {
    let mut new_devices = Vec::new();
    let mut back_online = Vec::new();
    let mut changed = Vec::new();

    for change in changes {
        match change {
            DeviceChange::New(device) => new_devices.push(device),
            DeviceChange::BackOnline { device, absent_for } => {
                back_online.push((device, absent_for))
            }
            DeviceChange::Changed {
                existing,
                new,
                ip_changed,
                vendor_changed,
            } => changed.push((existing, new, ip_changed, vendor_changed)),
        }
    }

    notify_new_devices(new_devices);
    notify_back_online(back_online);
    notify_changed(changed);
}

fn notify_new_devices(devices: Vec<Device>) {
    match devices.as_slice() {
        [] => {}
        [device] => {
            let (title, body) = render::render_new_device(device);
            persist_and_deliver(
                NotificationType::NewDeviceFound,
                title,
                body,
                Some(device.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().collect();
            let (title, body) = render::render_new_devices_summary(&refs);
            persist_and_deliver(NotificationType::NewDeviceFound, title, body, None);
        }
    }
}

fn notify_back_online(devices: Vec<(Device, Duration)>) {
    match devices.as_slice() {
        [] => {}
        [(device, absent_for)] => {
            let (title, body) =
                render::render_device_back_online(device, &render::duration_text(*absent_for));
            persist_and_deliver(
                NotificationType::DeviceOnlineAfterTime,
                title,
                body,
                Some(device.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().map(|(device, _)| device).collect();
            let (title, body) = render::render_back_online_summary(&refs);
            persist_and_deliver(NotificationType::DeviceOnlineAfterTime, title, body, None);
        }
    }
}

fn notify_changed(devices: Vec<(Device, Device, bool, bool)>) {
    match devices.as_slice() {
        [] => {}
        [(existing, new, ip_changed, vendor_changed)] => {
            let (title, body) =
                render::render_device_changed(existing, new, *ip_changed, *vendor_changed);
            persist_and_deliver(
                NotificationType::DeviceChanged,
                title,
                body,
                Some(new.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().map(|(_, new, _, _)| new).collect();
            let (title, body) = render::render_changed_summary(&refs);
            persist_and_deliver(NotificationType::DeviceChanged, title, body, None);
        }
    }
}

// Build a notification, persist it, and hand it to the delivery task. Delivery happens on a separate
// task (see `run_delivery`), so this returns as soon as the notification is persisted and never
// blocks the caller on the (potentially slow) Pushover HTTP call. A persistence failure is logged
// rather than propagated: a scan loop must keep running even if a single notification cannot be
// stored, and an unstored notification is not delivered.
fn persist_and_deliver(
    notification_type: NotificationType,
    title: String,
    body: String,
    mac_address: Option<String>,
) {
    let notification = Notification::new(
        Utc::now(),
        notification_type,
        title,
        body,
        true,
        mac_address,
    );

    let title = notification.title.clone();
    let body = notification.body.clone();
    if let Err(err) = db::notifications::insert(notification) {
        error!("Failed to record notification: {err}");
        return;
    }

    debug!("Queued notification for delivery: {title}");
    delivery::enqueue(title, body);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events;
    use crate::model::device_events::DeviceEventScanner;
    use chrono::{TimeZone, Utc};

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

    fn new_device_change(mac: &str, name: &str) -> DeviceChange {
        let mut device = sample_device(Some(name));
        device.mac_address = mac.to_string();
        DeviceChange::New(device)
    }

    #[tokio::test]
    async fn notifying_one_new_device_persists_a_single_device_notification() {
        crate::tests_common::setup().await;

        let mac = "fa:ce:fa:ce:00:02".to_string();
        let mut device = sample_device(Some("printer"));
        device.mac_address = mac.clone();

        // The delivery loop is not running in tests, so delivery is a no-op; the notification must
        // still be persisted regardless of whether it is ever delivered.
        notify(
            events::record_new_device(device, DeviceEventScanner::Arp)
                .into_iter()
                .collect(),
        );

        let notifications = db::notifications::list(None, None, None).unwrap();
        assert!(
            notifications
                .iter()
                .any(|n| n.mac_address.as_deref() == Some(mac.as_str())),
            "A single new-device sighting should persist a notification carrying its MAC"
        );
    }

    // The test DB is shared across tests, so assertions scope to unique device names rather than
    // global notification counts.
    #[tokio::test]
    async fn notifying_multiple_new_devices_consolidates_into_one_summary() {
        crate::tests_common::setup().await;

        notify(vec![
            new_device_change("fa:ce:fa:ce:01:01", "consolidate-printer"),
            new_device_change("fa:ce:fa:ce:01:02", "consolidate-laptop"),
        ]);

        let summaries: Vec<_> = db::notifications::list(None, None, None)
            .unwrap()
            .into_iter()
            .filter(|n| {
                n.notification_type == NotificationType::NewDeviceFound
                    && n.body.contains("consolidate-printer")
            })
            .collect();

        assert_eq!(
            summaries.len(),
            1,
            "Two new devices in one scan should produce a single consolidated notification"
        );
        let summary = &summaries[0];
        assert!(
            summary.mac_address.is_none(),
            "A multi-device notification must have an empty MAC address"
        );
        assert!(summary.title.contains('2'));
        assert!(summary.body.contains("consolidate-laptop"));
        // No private data, even in the consolidated body.
        assert!(!summary.body.contains("fa:ce:fa:ce:01:01"));
        assert!(!summary.body.contains("fa:ce:fa:ce:01:02"));
    }

    #[tokio::test]
    async fn notify_groups_changes_by_type() {
        crate::tests_common::setup().await;

        let mut existing = sample_device(Some("group-server"));
        existing.mac_address = "fa:ce:fa:ce:02:09".to_string();
        let mut changed = existing.clone();
        changed.ipv4_address = "192.168.1.250".to_string();

        // Two new devices (consolidated) plus one changed device (single) in the same scan.
        notify(vec![
            new_device_change("fa:ce:fa:ce:02:01", "group-printer"),
            new_device_change("fa:ce:fa:ce:02:02", "group-laptop"),
            DeviceChange::Changed {
                existing,
                new: changed,
                ip_changed: true,
                vendor_changed: false,
            },
        ]);

        let notifications = db::notifications::list(None, None, None).unwrap();
        let new_summaries = notifications
            .iter()
            .filter(|n| {
                n.notification_type == NotificationType::NewDeviceFound
                    && n.body.contains("group-printer")
            })
            .count();
        let changed_notifications: Vec<_> = notifications
            .iter()
            .filter(|n| {
                n.notification_type == NotificationType::DeviceChanged
                    && n.mac_address.as_deref() == Some("fa:ce:fa:ce:02:09")
            })
            .collect();

        assert_eq!(
            new_summaries, 1,
            "Both new devices collapse into one notification"
        );
        assert_eq!(changed_notifications.len(), 1);
        assert!(
            changed_notifications[0].mac_address.is_some(),
            "A single changed device keeps its MAC address"
        );
    }
}
