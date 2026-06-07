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
use once_cell::sync::OnceCell;
use tokio::sync::mpsc;

// A notification handed to the delivery loop. Delivery (a blocking Pushover HTTP call) runs on a
// dedicated task so a slow or unreachable Pushover can never stall the scan loops.
struct DeliveryRequest {
    title: String,
    body: String,
}

/// A notification-worthy change detected for one device during a sighting. The device event is
/// recorded when this is produced (see `classify_*`); sending the notification is deferred so
/// callers can either notify immediately (passive listeners, one device per event) or accumulate a
/// whole scan and send one consolidated notification per type (active scanners).
pub enum DeviceChange {
    New(Device),
    BackOnline {
        device: Device,
        absent_for: Duration,
    },
    Changed {
        existing: Device,
        new: Device,
        ip_changed: bool,
        vendor_changed: bool,
    },
}

// At most this many devices are listed individually in a consolidated summary body; any beyond are
// rolled into an "…and N more devices" line so the notification stays short.
const SUMMARY_LIST_LIMIT: usize = 3;

// Bounded so a stuck delivery loop cannot grow memory without limit; on overflow we drop and warn
// (delivery is best-effort, matching the "never stop the loop" policy in the scanner pipeline).
const DELIVERY_QUEUE_CAPACITY: usize = 100;

static DELIVERY_TX: OnceCell<mpsc::Sender<DeliveryRequest>> = OnceCell::new();

/// Owns the receiving end of the notification-delivery channel and delivers notifications off the
/// scan loop. Run this as its own task (see `main`); it returns only if the channel is closed.
pub async fn run_delivery() {
    let (tx, mut rx) = mpsc::channel::<DeliveryRequest>(DELIVERY_QUEUE_CAPACITY);
    if DELIVERY_TX.set(tx).is_err() {
        error!("Notification delivery loop started more than once; ignoring");
        return;
    }

    while let Some(request) = rx.recv().await {
        deliver(request).await;
    }
}

// Deliver a single notification according to the configured method. The Pushover call is blocking,
// so it runs on the blocking thread pool rather than the delivery task's async thread.
async fn deliver(request: DeliveryRequest) {
    match get_settings().notifications.method.as_str() {
        "pushover" => match &get_settings().notifications.pushover {
            Some(config) => {
                let config = config.clone();
                let result = tokio::task::spawn_blocking(move || {
                    pushover::send_message(&config, request.title, request.body)
                })
                .await;
                match result {
                    Ok(Ok(())) => {}
                    Ok(Err(err)) => error!("Failed to deliver notification via Pushover: {err}"),
                    Err(err) => error!("Notification delivery task panicked: {err}"),
                }
            }
            None => {
                error!(
                    "Notification method is 'pushover' but no [notifications.pushover] section is \
                     configured; cannot deliver notification."
                );
            }
        },
        other => {
            warn!("Notification method set to '{other}'. Set logs to 'info' to see notifications.");
            info!("Notification: {}", request.body);
        }
    }
}

// Hand a notification to the delivery loop. Never blocks: if the loop is not running (e.g. in
// tests) or its queue is full, the notification is logged and dropped rather than stalling the
// caller (a scan loop).
fn enqueue_delivery(title: String, body: String) {
    match DELIVERY_TX.get() {
        Some(tx) => {
            if let Err(err) = tx.try_send(DeliveryRequest { title, body }) {
                warn!("Notification delivery queue unavailable; dropping notification: {err}");
            }
        }
        None => {
            info!("Notification (delivery loop not running): {body}");
        }
    }
}

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

// Whether a re-sighting represents a real vendor change. A scanner that cannot deduce a vendor
// reports an empty string; that is not a change (db::devices::seen keeps the known vendor), so
// it must not raise a "vendor changed" notification either. Likewise, first deducing a vendor for a
// device that previously had none is not a change worth notifying about.
fn vendor_changed(existing: &str, new: &str) -> bool {
    !existing.is_empty() && !new.is_empty() && existing != new
}

// Whether a re-sighting represents a real IP-address change, mirroring vendor_changed. First
// learning an address for a device that previously had none (empty -> value, e.g. a device known
// only from a DHCP DISCOVER that later gets an ARP address) is not a change worth recording or
// notifying about. A sighting that carries no address (value -> empty) is likewise not a change;
// the pipeline already backfills the stored address in that case, so an empty `new` never reaches
// here, but the guard keeps this correct independently of the caller.
fn ip_changed(existing: &str, new: &str) -> bool {
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

// Render the duration a device was absent for display (whole seconds, e.g. "12d").
fn duration_text(absent_for: Duration) -> String {
    String::from(DurationString::from(Duration::from_secs(
        absent_for.as_secs(),
    )))
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

fn render_new_devices_summary(devices: &[&Device]) -> (String, String) {
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

fn render_back_online_summary(devices: &[&Device]) -> (String, String) {
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

fn render_changed_summary(devices: &[&Device]) -> (String, String) {
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

// Private helper function to record a notification and hand it off for delivery. Delivery happens
// on a separate task (see `run_delivery`), so this returns as soon as the notification is persisted
// and never blocks the caller on the (potentially slow) Pushover HTTP call.
fn send_notification(notification: Notification) -> Result<(), Box<dyn Error>> {
    debug!("About to record notification in database");

    let title = notification.title.clone();
    let body = notification.body.clone();
    db::notifications::insert(notification)?;

    debug!("Queued notification for delivery: {title}");
    enqueue_delivery(title, body);

    Ok(())
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
/// notification as well as the device event). Sending is deferred to `notify` so an active scan can
/// consolidate many new devices into one notification.
pub fn classify_new_device(device: Device, scanner: DeviceEventScanner) -> Option<DeviceChange> {
    if !record_event(DeviceEvent::new(
        device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::NewDevice,
        device.ipv4_address.clone(),
        device.vendor.clone(),
        scanner,
    )) {
        return None;
    }

    Some(DeviceChange::New(device))
}

/// Record the device events for a known device and return any notification-worthy changes (it may
/// return both a "back online" and a "changed" entry, or none). Every sighting records a baseline
/// `DeviceSeen` event (the history heartbeat, no notification); a return after the configured
/// absence and an IP/vendor change each additionally record their own event type and produce a
/// notification. Each event type is deduplicated independently within the configured window, so a
/// recent routine sighting never suppresses a genuine change or return. Sending is deferred to
/// `notify`.
pub fn classify_existing_device(
    existing_device: Device,
    new_device: Device,
    scanner: DeviceEventScanner,
) -> Vec<DeviceChange> {
    // Baseline presence heartbeat for the event history. Recorded (subject to its own dedup) for
    // every sighting and never raises a notification.
    record_event(DeviceEvent::new(
        new_device.mac_address.clone(),
        Utc::now(),
        DeviceEventType::DeviceSeen,
        new_device.ipv4_address.clone(),
        new_device.vendor.clone(),
        scanner.clone(),
    ));

    let mut changes = Vec::new();

    // The device came back online after not being seen for the configured period.
    let elapsed_since_last_seen: Duration = (Local::now().to_utc() - existing_device.last_seen)
        .to_std()
        .unwrap_or(Duration::from_secs(0));
    if elapsed_since_last_seen
        >= Duration::from(get_settings().notifications.notify_when_not_seen_for)
        && record_event(DeviceEvent::new(
            new_device.mac_address.clone(),
            Utc::now(),
            DeviceEventType::DeviceBackOnline,
            new_device.ipv4_address.clone(),
            new_device.vendor.clone(),
            scanner.clone(),
        ))
    {
        changes.push(DeviceChange::BackOnline {
            device: new_device.clone(),
            absent_for: elapsed_since_last_seen,
        });
    }

    // The device's vendor and/or IP changed.
    let ip_changed_flag = ip_changed(&existing_device.ipv4_address, &new_device.ipv4_address);
    let vendor_changed_flag = vendor_changed(&existing_device.vendor, &new_device.vendor);
    if (ip_changed_flag || vendor_changed_flag)
        && record_event(DeviceEvent::new(
            new_device.mac_address.clone(),
            Utc::now(),
            DeviceEventType::DeviceChanged,
            new_device.ipv4_address.clone(),
            new_device.vendor.clone(),
            scanner,
        ))
    {
        changes.push(DeviceChange::Changed {
            existing: existing_device,
            new: new_device,
            ip_changed: ip_changed_flag,
            vendor_changed: vendor_changed_flag,
        });
    }

    changes
}

/// Send notifications for the changes detected during a scan (or a single sighting). Changes are
/// grouped by notification type: a type with exactly one change produces the usual single-device
/// notification (carrying its MAC), while a type with two or more produces one consolidated summary
/// with an empty MAC. Recording happens here; delivery is handed to the delivery task.
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
            let (title, body) = render_new_device(device);
            send(
                NotificationType::NewDeviceFound,
                title,
                body,
                Some(device.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().collect();
            let (title, body) = render_new_devices_summary(&refs);
            send(NotificationType::NewDeviceFound, title, body, None);
        }
    }
}

fn notify_back_online(devices: Vec<(Device, Duration)>) {
    match devices.as_slice() {
        [] => {}
        [(device, absent_for)] => {
            let (title, body) = render_device_back_online(device, &duration_text(*absent_for));
            send(
                NotificationType::DeviceOnlineAfterTime,
                title,
                body,
                Some(device.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().map(|(device, _)| device).collect();
            let (title, body) = render_back_online_summary(&refs);
            send(NotificationType::DeviceOnlineAfterTime, title, body, None);
        }
    }
}

fn notify_changed(devices: Vec<(Device, Device, bool, bool)>) {
    match devices.as_slice() {
        [] => {}
        [(existing, new, ip_changed, vendor_changed)] => {
            let (title, body) = render_device_changed(existing, new, *ip_changed, *vendor_changed);
            send(
                NotificationType::DeviceChanged,
                title,
                body,
                Some(new.mac_address.clone()),
            );
        }
        many => {
            let refs: Vec<&Device> = many.iter().map(|(_, new, _, _)| new).collect();
            let (title, body) = render_changed_summary(&refs);
            send(NotificationType::DeviceChanged, title, body, None);
        }
    }
}

// Build and record a notification, logging (rather than propagating) a persistence failure: a scan
// loop must keep running even if a single notification cannot be stored.
fn send(
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
    if let Err(err) = send_notification(notification) {
        error!("Failed to record notification: {err}");
    }
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
        classify_existing_device(device.clone(), device.clone(), DeviceEventScanner::Arp);
        classify_existing_device(device.clone(), device.clone(), DeviceEventScanner::Arp);

        let after_arp = db::device_events::list(Some(mac.clone()), None, None, None).unwrap();
        assert_eq!(
            after_arp.len(),
            1,
            "A repeated same-scanner sighting should be deduplicated"
        );

        // A sighting from a different scanner is not a duplicate and is recorded.
        classify_existing_device(device.clone(), device.clone(), DeviceEventScanner::Mdns);

        let after_mdns = db::device_events::list(Some(mac), None, None, None).unwrap();
        assert_eq!(
            after_mdns.len(),
            2,
            "A sighting from a different scanner should be recorded"
        );
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
            classify_new_device(device, DeviceEventScanner::Arp)
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
        notify(classify_existing_device(
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
        notify(classify_existing_device(
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

        let changes = classify_existing_device(existing, new, DeviceEventScanner::Arp);

        assert!(
            !changes
                .iter()
                .any(|change| matches!(change, DeviceChange::Changed { .. })),
            "Filling a previously empty IP must not be classified as a change"
        );
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
    async fn changed_sighting_records_a_changed_event_and_notification() {
        crate::tests_common::setup().await;

        // A known device, recently seen (so not "back online"), now reports a different IP.
        let mut existing = sample_device(Some("changed-device"));
        existing.mac_address = "fa:ce:fa:ce:05:01".to_string();
        existing.last_seen = Utc::now();
        let mut new = existing.clone();
        new.ipv4_address = "192.168.1.123".to_string();
        let mac = existing.mac_address.clone();

        notify(classify_existing_device(existing, new, DeviceEventScanner::Arp));

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

        notify(classify_existing_device(existing, new, DeviceEventScanner::Arp));

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

        notify(classify_existing_device(existing, new, DeviceEventScanner::Arp));

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

    fn new_device_change(mac: &str, name: &str) -> DeviceChange {
        let mut device = sample_device(Some(name));
        device.mac_address = mac.to_string();
        DeviceChange::New(device)
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
