mod error;
mod pushover;

use std::error::Error;
use std::fmt::Write;
use std::time::Duration;

use crate::db;
use crate::model::device_events::{DeviceEvent, DeviceEventScanner, DeviceEventType};
use crate::model::devices::Device;
use crate::model::notifications::Notification;
use crate::model::notifications::NotificationType;
use crate::settings::get_settings;
use chrono::{Local, Utc};
use duration_string::DurationString;
use log::{debug, error, info, warn};

// Device name for display in messages; falls back to "(unknown)" for devices with no
// mDNS-discovered hostname (e.g. those found only via ARP).
fn display_name(device: &Device) -> &str {
    device
        .name
        .as_deref()
        .filter(|name| !name.is_empty())
        .unwrap_or("(unknown)")
}

// Identifier used in notification titles, so a Pushover preview is triageable
// without opening the notification. Prefers the hostname, then the vendor, then a
// short MAC suffix as a last resort.
fn title_identity(device: &Device) -> String {
    if let Some(name) = device.name.as_deref().filter(|name| !name.is_empty()) {
        return name.to_string();
    }
    if !device.vendor.is_empty() {
        return device.vendor.clone();
    }
    let mac = &device.mac_address;
    let suffix = if mac.len() > 8 {
        &mac[mac.len() - 8..]
    } else {
        mac
    };
    format!("MAC ...{suffix}")
}

fn device_type_or_unknown(device: &Device) -> &str {
    if device.device_type.is_empty() {
        "Unknown"
    } else {
        &device.device_type
    }
}

fn registration_line(device: &Device) -> String {
    if device.is_registered {
        if device.owner.is_empty() {
            "Registered".to_string()
        } else {
            format!("Registered to {}", device.owner)
        }
    } else {
        "Not registered".to_string()
    }
}

// Whether a re-sighting represents a real vendor change. A scanner that cannot deduce a vendor
// reports an empty string; that is not a change (db::devices::seen keeps the known vendor), so
// it must not raise a "vendor changed" notification either. Likewise, first deducing a vendor for a
// device that previously had none is not a change worth notifying about.
fn vendor_changed(existing: &str, new: &str) -> bool {
    !existing.is_empty() && !new.is_empty() && existing != new
}

fn render_new_device(device: &Device) -> (String, String) {
    let title = format!("New device on your network: {}", title_identity(device));
    let mut body = String::new();
    writeln!(
        body,
        "A device that has not been seen before joined your network."
    )
    .unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Device").unwrap();
    writeln!(body, "  Name: {}", display_name(device)).unwrap();
    writeln!(body, "  MAC address: {}", device.mac_address).unwrap();
    writeln!(body, "  IP address: {}", device.ipv4_address).unwrap();
    writeln!(body, "  Vendor: {}", device.vendor).unwrap();
    writeln!(body, "  Type: {}", device_type_or_unknown(device)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Status").unwrap();
    writeln!(body, "  {}", registration_line(device)).unwrap();
    writeln!(body).unwrap();
    write!(
        body,
        "If you do not recognise this device, consider investigating before \
         granting it continued access."
    )
    .unwrap();
    (title, body)
}

fn render_device_back_online(device: &Device, duration_text: &str) -> (String, String) {
    let title = format!(
        "Device back online after {}: {}",
        duration_text,
        title_identity(device)
    );
    let mut body = String::new();
    writeln!(
        body,
        "A known device returned to your network after being absent."
    )
    .unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Device").unwrap();
    writeln!(body, "  Name: {}", display_name(device)).unwrap();
    writeln!(body, "  MAC address: {}", device.mac_address).unwrap();
    writeln!(body, "  IP address: {}", device.ipv4_address).unwrap();
    writeln!(body, "  Vendor: {}", device.vendor).unwrap();
    writeln!(body, "  Type: {}", device_type_or_unknown(device)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Status").unwrap();
    writeln!(body, "  {}", registration_line(device)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Activity").unwrap();
    write!(body, "  Absent for: {duration_text}").unwrap();
    (title, body)
}

fn render_device_changed(
    existing: &Device,
    new: &Device,
    ip_changed: bool,
    vendor_changed_flag: bool,
) -> (String, String) {
    let identity = title_identity(new);
    let title = match (ip_changed, vendor_changed_flag) {
        (true, true) => format!("Device changed IP and vendor: {identity}"),
        (true, false) => format!("Device changed IP: {identity}"),
        (false, true) => format!("Device changed vendor: {identity}"),
        // Caller guards against calling with both flags false.
        (false, false) => format!("Device changed: {identity}"),
    };
    let mut body = String::new();
    writeln!(body, "An existing device's network details changed.").unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Device").unwrap();
    writeln!(body, "  Name: {}", display_name(new)).unwrap();
    writeln!(body, "  MAC address: {} (unchanged)", new.mac_address).unwrap();
    writeln!(body, "  Type: {}", device_type_or_unknown(new)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Status").unwrap();
    writeln!(body, "  {}", registration_line(new)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Changes").unwrap();
    if ip_changed {
        writeln!(
            body,
            "  IP address: {} -> {}",
            existing.ipv4_address, new.ipv4_address
        )
        .unwrap();
    }
    if vendor_changed_flag {
        writeln!(body, "  Vendor: {} -> {}", existing.vendor, new.vendor).unwrap();
    }
    if vendor_changed_flag {
        writeln!(body).unwrap();
        write!(
            body,
            "A vendor change on the same MAC address is unusual and may indicate \
             MAC spoofing."
        )
        .unwrap();
    }
    (title, body)
}

// Private helper function to deliver messages
fn send_notification(notification: Notification) -> Result<(), Box<dyn Error>> {
    debug!("About to record notification in database");
    db::notifications::insert(notification.clone())?;

    debug!("About to send notification ({notification}).");

    match get_settings().notifications.method.as_str() {
        "pushover" => {
            pushover::send_message(notification.title, notification.body)?;
        }
        other => {
            warn!("Notification method set to '{other}'. Set logs to 'info' to see notifications.");
            info!("Notification: {}", notification.body);
        }
    };

    Ok(())
}

/// Record a device event, skipping it when the same scanner already recorded an event for the
/// same device (same MAC and IPv4) within the configured deduplication window. This keeps the
/// events table from filling with near-identical rows when a scanner sees a device repeatedly.
fn record_event(event: DeviceEvent) {
    let window: Duration = get_settings().device_events.deduplication_window.into();
    let since = Utc::now() - chrono::Duration::from_std(window).unwrap_or_default();

    match db::device_events::recent_duplicate_exists(
        &event.mac_address,
        &event.ipv4_address,
        &event.scanner,
        since,
    ) {
        Ok(true) => {
            debug!("Skipping duplicate device event within window: {event}");
            return;
        }
        Ok(false) => {}
        // On a check error, fall through and record the event rather than silently drop it.
        Err(err) => error!("Device event deduplication check failed ({err}); recording event"),
    }

    if let Err(err) = db::device_events::insert(event) {
        error!("Failed to record device event: {err}");
    }
}

pub fn trigger_new_device(
    device: Device,
    scanner: DeviceEventScanner,
) -> Result<(), Box<dyn Error>> {
    record_event(DeviceEvent::new(
        device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::NewDevice,
        device.ipv4_address.clone(),
        device.vendor.clone(),
        scanner,
    ));

    let (title, body) = render_new_device(&device);
    let notification = Notification::new(
        Utc::now(),
        NotificationType::NewDeviceFound,
        title,
        body,
        true,
        Some(device.mac_address.clone()),
    );

    send_notification(notification)?;
    Ok(())
}

pub fn trigger_existing_device(
    existing_device: Device,
    new_device: Device,
    scanner: DeviceEventScanner,
) -> Result<(), Box<dyn Error>> {
    record_event(DeviceEvent::new(
        new_device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::DeviceSeen,
        new_device.ipv4_address.clone(),
        new_device.vendor.clone(),
        scanner,
    ));

    // Notify if the device comes back online after not being seen for the configured period
    let elapsed_since_last_seen: Duration = (Local::now().to_utc() - existing_device.last_seen)
        .to_std()
        .unwrap_or(Duration::from_secs(0));

    if elapsed_since_last_seen
        >= Duration::from(get_settings().notifications.notify_when_not_seen_for)
    {
        let duration_text = String::from(DurationString::from(Duration::from_secs(
            elapsed_since_last_seen.as_secs(),
        )));
        let (title, body) = render_device_back_online(&new_device, &duration_text);
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceOnlineAfterTime,
            title,
            body,
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    }

    // Notify if the devices vendor and/or IP changed
    let ip_changed = existing_device.ipv4_address != new_device.ipv4_address;
    let vendor_changed_flag = vendor_changed(&existing_device.vendor, &new_device.vendor);

    if ip_changed || vendor_changed_flag {
        let (title, body) =
            render_device_changed(&existing_device, &new_device, ip_changed, vendor_changed_flag);
        let notification = Notification::new(
            Utc::now(),
            NotificationType::DeviceChanged,
            title,
            body,
            true,
            Some(new_device.mac_address.clone()),
        );

        send_notification(notification)?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
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
    fn title_identity_prefers_name_then_vendor_then_mac_suffix() {
        let mut device = sample_device(Some("bobs-iphone.local"));
        assert_eq!(title_identity(&device), "bobs-iphone.local");

        device.name = None;
        assert_eq!(title_identity(&device), "Apple, Inc.");

        device.vendor = "".to_string();
        assert_eq!(title_identity(&device), "MAC ...dd:ee:ff");
    }

    #[test]
    fn registration_line_covers_all_cases() {
        let mut device = sample_device(None);
        assert_eq!(registration_line(&device), "Not registered");

        device.is_registered = true;
        assert_eq!(registration_line(&device), "Registered");

        device.owner = "Alice".to_string();
        assert_eq!(registration_line(&device), "Registered to Alice");
    }

    #[test]
    fn device_type_falls_back_to_unknown_when_empty() {
        let mut device = sample_device(None);
        assert_eq!(device_type_or_unknown(&device), "Smartphone");

        device.device_type = "".to_string();
        assert_eq!(device_type_or_unknown(&device), "Unknown");
    }

    #[test]
    fn new_device_body_includes_all_fields_and_security_hint() {
        let device = sample_device(Some("printer.local"));
        let (title, body) = render_new_device(&device);

        assert_eq!(title, "New device on your network: printer.local");
        assert!(body.contains("Name: printer.local"));
        assert!(body.contains("MAC address: aa:bb:cc:dd:ee:ff"));
        assert!(body.contains("IP address: 192.168.1.42"));
        assert!(body.contains("Vendor: Apple, Inc."));
        assert!(body.contains("Type: Smartphone"));
        assert!(body.contains("Not registered"));
        assert!(body.contains("If you do not recognise this device"));
    }

    #[test]
    fn new_device_body_uses_unknown_for_missing_name() {
        let device = sample_device(None);
        let (_, body) = render_new_device(&device);
        assert!(body.contains("Name: (unknown)"));
    }

    #[test]
    fn device_back_online_body_includes_duration_and_registration() {
        let mut device = sample_device(Some("bobs-iphone.local"));
        device.is_registered = true;
        device.owner = "Bob".to_string();

        let (title, body) = render_device_back_online(&device, "12d");

        assert_eq!(
            title,
            "Device back online after 12d: bobs-iphone.local"
        );
        assert!(body.contains("Registered to Bob"));
        assert!(body.contains("Absent for: 12d"));
    }

    #[test]
    fn device_changed_ip_only_shows_ip_row_without_spoofing_hint() {
        let existing = sample_device(Some("bobs-iphone.local"));
        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.99".to_string();

        let (title, body) = render_device_changed(&existing, &new, true, false);

        assert_eq!(title, "Device changed IP: bobs-iphone.local");
        assert!(body.contains("IP address: 192.168.1.42 -> 192.168.1.99"));
        assert!(!body.contains("Vendor:"));
        assert!(!body.contains("MAC spoofing"));
        assert!(body.contains("MAC address: aa:bb:cc:dd:ee:ff (unchanged)"));
    }

    #[test]
    fn device_changed_vendor_only_includes_spoofing_hint() {
        let existing = sample_device(Some("bobs-iphone.local"));
        let mut new = existing.clone();
        new.vendor = "Samsung Electronics".to_string();

        let (title, body) = render_device_changed(&existing, &new, false, true);

        assert_eq!(title, "Device changed vendor: bobs-iphone.local");
        assert!(body.contains("Vendor: Apple, Inc. -> Samsung Electronics"));
        assert!(!body.contains("IP address: 192."));
        assert!(body.contains("MAC spoofing"));
    }

    #[test]
    fn device_changed_both_shows_both_rows_and_spoofing_hint() {
        let existing = sample_device(Some("bobs-iphone.local"));
        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.99".to_string();
        new.vendor = "Samsung Electronics".to_string();

        let (title, body) = render_device_changed(&existing, &new, true, true);

        assert_eq!(title, "Device changed IP and vendor: bobs-iphone.local");
        assert!(body.contains("IP address: 192.168.1.42 -> 192.168.1.99"));
        assert!(body.contains("Vendor: Apple, Inc. -> Samsung Electronics"));
        assert!(body.contains("MAC spoofing"));
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
        trigger_existing_device(device.clone(), device.clone(), DeviceEventScanner::Arp).unwrap();
        trigger_existing_device(device.clone(), device.clone(), DeviceEventScanner::Arp).unwrap();

        let after_arp = db::device_events::list(Some(mac.clone()), None, None, None).unwrap();
        assert_eq!(
            after_arp.len(),
            1,
            "A repeated same-scanner sighting should be deduplicated"
        );

        // A sighting from a different scanner is not a duplicate and is recorded.
        trigger_existing_device(device.clone(), device.clone(), DeviceEventScanner::Mdns).unwrap();

        let after_mdns = db::device_events::list(Some(mac), None, None, None).unwrap();
        assert_eq!(
            after_mdns.len(),
            2,
            "A sighting from a different scanner should be recorded"
        );
    }
}
