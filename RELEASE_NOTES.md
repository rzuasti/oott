# OOTT Release Notes

<!--
Format
======
- Newest version first.
- One `## vX.Y.Z — YYYY-MM-DD` section per release (the tag, an em dash, the date).
- Everything between a version heading and the next `## v…` heading (or end of
  file) is that release's notes, and is what `release.sh` publishes to GitHub.
- Write the notes for a version BEFORE running `release.sh`; the script reads
  the matching section by tag and aborts if it cannot find it.
- Keep this header comment in place; the extractor ignores it.
-->

## v0.1.3 — 2026-06-07

A release focused on iOS readiness, app branding, and home/device UI polish.

### Features
- New devices now offer a "How to identify this device" guide, a dialog that
  walks through practical steps for recognising an unregistered device on the
  network.
- The OOTT brand icon is now the app launcher icon across every platform
  (iOS, Android, web and Windows).

### Improvements
- On iOS the app now requests the local-network permission at launch, so
  scanning works without a manual trip to Settings.
- Top-level tabs now crossfade when switching instead of using the iOS slide
  transition.
- The home page no longer shows a redundant "Notifications" title, and the
  empty new-notifications message was reworded.
- Normal device-seen dots in the event history chart are smaller, so genuine
  change and return markers stand out more.

### Internal
- Added an iOS TestFlight build pipeline via Codemagic, including persistent
  code signing, a safe initial build number, and an export-encryption
  exemption declaration for App Store submission.

## v0.1.2 — 2026-06-07

A maintenance release focused on more accurate change/return notifications and
a fix for the API docs link when running under the bundled server.

### Fixes
- The "API Docs" link now works when the app is served from the backend (e.g.
  in Docker). The origin-relative `/api/docs` path is resolved against the
  current page so it carries a scheme and host; absolute URLs pass through
  unchanged.
- A device gaining its first IP address no longer raises a spurious "changed"
  notification (an empty → value fill is no longer treated as a change).
- A recent routine sighting no longer suppresses a genuine change or
  return-online notification. Each event kind is now deduplicated
  independently, keyed on device, scanner and event type rather than on the
  reported address.

### Improvements
- Each known-device sighting now records a specific event type — a baseline
  `DeviceSeen` heartbeat (no notification), plus `DeviceChanged` and
  `DeviceBackOnline`. The device history chart reads the recorded event type
  directly for its markers and tooltips instead of inferring it from the
  device's current state.

### Internal
- The backend events code was split into focused modules: `events` (device-event
  recording) with a pure change-detection submodule, a new `notifications`
  module owning rendering, delivery and sending, and a shared `DeviceChange`
  contract in `model`. Data flows one way: events produce changes,
  notifications consume them.

## v0.1.1 — 2026-06-06

A maintenance release with bug fixes and small refinements on top of v0.1.0.

### Fixes
- Fixed a blank `/web` UI when running under the bundled server: the Flutter web
  bundle is now built with `--base-href=/web/` so its asset URLs resolve against
  the mount point instead of the site root.
- The bare `/` URL now redirects to the `/web` UI.

### Improvements
- Added an `/api` → `/api/docs` redirect and corrected the root guidance text to
  point at the API explorer (`/api/docs`).
- Added an "API Docs" link to the wide navigation rail.
- New-device notifications no longer include the status block, which only ever
  read "Not registered" and added no information.
- Absent names, vendors, and device types now render consistently as a dash,
  both in notifications and across the web UI.

## v0.1.0 — 2026-06-06

First public release of OOTT — an easy to setup network device discovery and
alert system that notifies you when new or unknown devices join your local area
network.

### Highlights
- Regular network scanning using ARP probes, plus mDNS/Bonjour, SSDP/UPnP and
  DHCP discovery, and an optional SNMP scanner that reads a gateway's ARP table.
  Each scanner can be enabled or disabled independently.
- Alerts when a new device is found, when a device changes its IP address or
  network interface vendor (by MAC address), and when a device comes back
  online after a configurable offline period. Pushover delivery, or log-only.
- Device type inference from MAC vendor data.
- Web front-end (Flutter/Material 3) for configuration and browsing stored data,
  responsive across desktop, tablet and phone, with native iOS and Android apps.
  Includes selectable themes (Gruvbox Dark by default), paginated and sortable
  device and notification lists, filtering, and activity charts.
- Rust backend exposing a documented REST API (OpenAPI / Swagger UI) backed by
  SQLite with incremental migrations.
- Configurable history retention with automatic daily purging, and per-scanner
  event deduplication to keep the database compact.

### Configuration & security
- Single config file in TOML; every option falls back to a
  sensible default except for a small required set.
- Backend access is gated by an API key. OOTT has no built-in user accounts —
  put it behind a reverse-proxy auth layer if you need login/SSO. See the
  [README](README.md) for HTTPS, domain-name and access-control guidance.

### Installation
- Available as a pre-built Docker image (`rzuasti/oott`) and as a NixOS flake
  module. See the [README](README.md) for deployment and configuration details.
