use std::fmt::Write;
use std::time::Duration;

use duration_string::DurationString;

use crate::model::devices::Device;

// At most this many devices are listed individually in a consolidated summary body; any beyond are
// rolled into an "…and N more devices" line so the notification stays short.
const SUMMARY_LIST_LIMIT: usize = 3;

// Placeholder shown in notifications for a value the scanners could not determine. A plain ASCII
// hyphen (rather than an em dash) avoids encoding issues across notification transports.
const UNKNOWN_PLACEHOLDER: &str = "-";

// Device name for display in messages; falls back to the placeholder for devices with no
// mDNS-discovered hostname (e.g. those found only via ARP).
fn display_name(device: &Device) -> &str {
    device
        .name
        .as_deref()
        .filter(|name| !name.is_empty())
        .unwrap_or(UNKNOWN_PLACEHOLDER)
}

// Identifier used in notification titles, so a Pushover preview is triageable
// without opening the notification. Prefers the hostname, then the vendor, then a
// masked MAC suffix (last two octets only) as a last resort, so no full MAC is ever exposed.
fn title_identity(device: &Device) -> String {
    if let Some(name) = device.name.as_deref().filter(|name| !name.is_empty()) {
        return name.to_string();
    }
    if !device.vendor.is_empty() {
        return device.vendor.clone();
    }
    let mac = &device.mac_address;
    let suffix = if mac.len() > 5 {
        &mac[mac.len() - 5..]
    } else {
        mac
    };
    format!("device …{suffix}")
}

fn device_type_or_placeholder(device: &Device) -> &str {
    if device.device_type.is_empty() {
        UNKNOWN_PLACEHOLDER
    } else {
        &device.device_type
    }
}

fn vendor_or_placeholder(device: &Device) -> &str {
    if device.vendor.is_empty() {
        UNKNOWN_PLACEHOLDER
    } else {
        &device.vendor
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

// Render the duration a device was absent for display (whole seconds, e.g. "12d").
pub(super) fn duration_text(absent_for: Duration) -> String {
    String::from(DurationString::from(Duration::from_secs(
        absent_for.as_secs(),
    )))
}

pub(super) fn render_new_device(device: &Device) -> (String, String) {
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
    writeln!(body, "  Vendor: {}", vendor_or_placeholder(device)).unwrap();
    writeln!(body, "  Type: {}", device_type_or_placeholder(device)).unwrap();
    writeln!(body).unwrap();
    write!(
        body,
        "If you do not recognise this device, consider investigating before \
         granting it continued access."
    )
    .unwrap();
    (title, body)
}

pub(super) fn render_device_back_online(device: &Device, duration_text: &str) -> (String, String) {
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
    writeln!(body, "  Vendor: {}", vendor_or_placeholder(device)).unwrap();
    writeln!(body, "  Type: {}", device_type_or_placeholder(device)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Status").unwrap();
    writeln!(body, "  {}", registration_line(device)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Activity").unwrap();
    write!(body, "  Absent for: {duration_text}").unwrap();
    (title, body)
}

pub(super) fn render_device_changed(
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
    writeln!(body, "  Type: {}", device_type_or_placeholder(new)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Status").unwrap();
    writeln!(body, "  {}", registration_line(new)).unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Changes").unwrap();
    if ip_changed {
        // The address values are private and deliberately omitted; the change itself is reported.
        writeln!(body, "  IP address changed").unwrap();
    }
    if vendor_changed_flag {
        writeln!(body, "  Vendor: {} -> {}", existing.vendor, new.vendor).unwrap();
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

// One line describing a device in a consolidated summary: its name, plus vendor and type when
// known. No MAC or IP address is included.
fn summary_device_line(device: &Device) -> String {
    let mut line = display_name(device).to_string();
    let mut details = Vec::new();
    if !device.vendor.is_empty() {
        details.push(device.vendor.clone());
    }
    if !device.device_type.is_empty() {
        details.push(device.device_type.clone());
    }
    if !details.is_empty() {
        write!(line, " ({})", details.join(", ")).unwrap();
    }
    line
}

// Append the capped device list shared by every summary body: up to SUMMARY_LIST_LIMIT devices,
// then an "…and N more devices" line when there are more.
fn write_device_summary(body: &mut String, devices: &[&Device]) {
    for device in devices.iter().take(SUMMARY_LIST_LIMIT) {
        writeln!(body, "  - {}", summary_device_line(device)).unwrap();
    }
    if devices.len() > SUMMARY_LIST_LIMIT {
        writeln!(
            body,
            "  …and {} more devices",
            devices.len() - SUMMARY_LIST_LIMIT
        )
        .unwrap();
    }
}

pub(super) fn render_new_devices_summary(devices: &[&Device]) -> (String, String) {
    let title = format!("{} new devices found on your network", devices.len());
    let mut body = String::new();
    writeln!(
        body,
        "{} devices that have not been seen before joined your network.",
        devices.len()
    )
    .unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Devices").unwrap();
    write_device_summary(&mut body, devices);
    writeln!(body).unwrap();
    write!(
        body,
        "If you do not recognise these devices, consider investigating before \
         granting them continued access."
    )
    .unwrap();
    (title, body)
}

pub(super) fn render_back_online_summary(devices: &[&Device]) -> (String, String) {
    let title = format!("{} devices back online", devices.len());
    let mut body = String::new();
    writeln!(
        body,
        "{} known devices returned to your network after being absent.",
        devices.len()
    )
    .unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Devices").unwrap();
    write_device_summary(&mut body, devices);
    (title, body)
}

pub(super) fn render_changed_summary(devices: &[&Device]) -> (String, String) {
    let title = format!("{} devices changed on your network", devices.len());
    let mut body = String::new();
    writeln!(
        body,
        "{} existing devices changed their network details (IP address and/or vendor).",
        devices.len()
    )
    .unwrap();
    writeln!(body).unwrap();
    writeln!(body, "Devices").unwrap();
    write_device_summary(&mut body, devices);
    writeln!(body).unwrap();
    write!(
        body,
        "A vendor change on the same device is unusual and may indicate MAC spoofing."
    )
    .unwrap();
    (title, body)
}

#[cfg(test)]
mod tests {
    use super::*;
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

    #[test]
    fn title_identity_prefers_name_then_vendor_then_masked_mac_suffix() {
        let mut device = sample_device(Some("bobs-iphone.local"));
        assert_eq!(title_identity(&device), "bobs-iphone.local");

        device.name = None;
        assert_eq!(title_identity(&device), "Apple, Inc.");

        // No name and no vendor: fall back to a masked suffix (last two octets only), never the
        // full MAC.
        device.vendor = "".to_string();
        assert_eq!(title_identity(&device), "device …ee:ff");
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
    fn device_type_falls_back_to_placeholder_when_empty() {
        let mut device = sample_device(None);
        assert_eq!(device_type_or_placeholder(&device), "Smartphone");

        device.device_type = "".to_string();
        assert_eq!(device_type_or_placeholder(&device), UNKNOWN_PLACEHOLDER);
    }

    #[test]
    fn vendor_falls_back_to_placeholder_when_empty() {
        let mut device = sample_device(None);
        assert_eq!(vendor_or_placeholder(&device), "Apple, Inc.");

        device.vendor = "".to_string();
        assert_eq!(vendor_or_placeholder(&device), UNKNOWN_PLACEHOLDER);
    }

    #[test]
    fn new_device_body_uses_placeholder_for_missing_vendor() {
        let mut device = sample_device(Some("printer.local"));
        device.vendor = "".to_string();
        let (_, body) = render_new_device(&device);
        assert!(body.contains(&format!("Vendor: {UNKNOWN_PLACEHOLDER}")));
    }

    #[test]
    fn new_device_body_includes_fields_and_security_hint_without_private_data() {
        let device = sample_device(Some("printer.local"));
        let (title, body) = render_new_device(&device);

        assert_eq!(title, "New device on your network: printer.local");
        assert!(body.contains("Name: printer.local"));
        assert!(body.contains("Vendor: Apple, Inc."));
        assert!(body.contains("Type: Smartphone"));
        // New devices are never registered, so the status block is omitted entirely.
        assert!(!body.contains("Status"));
        assert!(!body.contains("registered"));
        assert!(body.contains("If you do not recognise this device"));
        // Private data must never appear in the body.
        assert!(!body.contains("aa:bb:cc:dd:ee:ff"));
        assert!(!body.contains("192.168.1.42"));
    }

    #[test]
    fn new_device_body_uses_placeholder_for_missing_name() {
        let device = sample_device(None);
        let (_, body) = render_new_device(&device);
        assert!(body.contains(&format!("Name: {UNKNOWN_PLACEHOLDER}")));
    }

    #[test]
    fn device_back_online_body_includes_duration_and_registration() {
        let mut device = sample_device(Some("bobs-iphone.local"));
        device.is_registered = true;
        device.owner = "Bob".to_string();

        let (title, body) = render_device_back_online(&device, "12d");

        assert_eq!(title, "Device back online after 12d: bobs-iphone.local");
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
        assert!(body.contains("IP address changed"));
        assert!(!body.contains("Vendor:"));
        assert!(!body.contains("MAC spoofing"));
        // The changed IP values and the MAC are private and must not appear.
        assert!(!body.contains("192.168.1.42"));
        assert!(!body.contains("192.168.1.99"));
        assert!(!body.contains("aa:bb:cc:dd:ee:ff"));
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
        assert!(body.contains("IP address changed"));
        assert!(body.contains("Vendor: Apple, Inc. -> Samsung Electronics"));
        assert!(body.contains("MAC spoofing"));
        assert!(!body.contains("192.168.1.42"));
        assert!(!body.contains("192.168.1.99"));
    }

    #[test]
    fn summary_lists_at_most_three_devices_then_counts_the_rest() {
        let devices: Vec<Device> = (0..5)
            .map(|i| {
                let mut device = sample_device(Some(&format!("device-{i}")));
                device.mac_address = format!("aa:bb:cc:00:00:0{i}");
                device
            })
            .collect();
        let refs: Vec<&Device> = devices.iter().collect();

        let (_, body) = render_new_devices_summary(&refs);

        assert!(body.contains("device-0"));
        assert!(body.contains("device-1"));
        assert!(body.contains("device-2"));
        assert!(!body.contains("device-3"));
        assert!(body.contains("…and 2 more devices"));
    }
}
