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

## v0.2.3 — 2026-06-15

A small fix-and-polish release.

### Fixes
- **"Device changed" notifications.** A registered, typed device that changed
  its IP or vendor was reported in the notification as "Not registered" with
  type "-". The notification now describes the device as it is stored.

### Improvements
- The first-run experience now opens straight into the backend-config dialog,
  with the welcome message folded into it and its actions kept on a single row.

## v0.2.2 — 2026-06-12

A polish release: more themes to choose from, the ability to permanently delete
a device, and a round of UI and iOS push refinements.

### Features
- **More themes.** Five new selectable themes join Catppuccin Mocha and Gruvbox
  Dark — Catppuccin Latte, Dracula, Alucard, Nord, and Tokyo Night — each using
  the same shared theme builder so they stay visually consistent.
- **Permanent device deletion.** Not-registered devices can now be deleted
  outright (from the device detail screen or the list row), and the Forget
  dialog gains an opt-in "permanently delete" checkbox that erases the device
  and its events for good.

### Fixes
- **iOS foreground push.** Push notifications now display as a banner on iOS
  even while the app is open, instead of being silently suppressed or
  double-shown.
- **Narrow-screen layout.** The device detail action buttons now wrap instead
  of overflowing horizontally on phone widths.

### Improvements
- Button emphasis follows Material 3 more closely: a single filled primary
  action, error-colored text buttons for destructive actions, and the Test
  button demoted to filled-tonal.
- The backend-config Test button flashes red when a connection test fails.
- Snackbars now render above dialogs via a top-level messenger host.
- The Android adaptive launcher icon shows a larger OOTT wordmark.
- The About screen links to the project website instead of the source and
  license.

### Internal
- The backend adds `db::devices::delete` and a `DELETE
  /api/devices/{mac}/permanently` endpoint (wired into OpenAPI), both covered by
  tests.
- The README documents the one-time paid app model, and the project reserves the
  "OOTT" name and logo as a trademark while keeping the source under AGPL-3.0.

## v0.2.1 — 2026-06-09

A follow-up to v0.2.0 that makes mobile push notifications actually arrive on
iOS, and adds a way to verify delivery yourself.

### Features
- **Send test notification.** Settings now has a "Send test notification" button
  that asks the backend to push a test alert to every registered device and
  reports back how many devices it reached, so you can confirm push is working
  end to end.

### Fixes
- **iOS push delivery.** Firebase is now initialised at startup and the app
  waits for the native APNs token before requesting its FCM token, so iOS
  devices reliably obtain a push token instead of leaving it null. The push
  token is also re-registered on each launch to recover from rotation.

### Internal
- The iOS `AppDelegate` and `push_service` surface the native APNs registration
  outcome for diagnostics, and `push_service` was refactored for clarity.
- The backend's test-notification endpoint returns the delivered device count.

## v0.2.0 — 2026-06-09

The headline of this release is mobile push notifications: OOTT can now alert
you on your phone when a new or changed device appears, without keeping the app
open. The settings screen was also reorganised, and there are several transition
and caching fixes.

### Features
- **Push notifications.** When the backend's notification method is set to
  "push", the app can register each device to receive alerts through Firebase
  Cloud Messaging, relayed by a small project-owned Cloud Function. Payloads are
  privacy-preserving: only the already-sanitized alert title and body are sent —
  no MAC, IP, or device data, and tapping a notification simply opens the app.
  A per-device push toggle in settings turns it on (shown only on platforms that
  support push and when the backend is configured for it).
- **Reorganised settings.** Backend URL and API key now live in a dedicated
  Test/Save dialog reachable via "Re-configure", and open automatically on first
  run. The settings screen shows the connection read-only (with a key reveal)
  and groups Theme and Push into an "App settings" card; theme and push changes
  apply immediately.

### Improvements
- Duration displays (e.g. the passive scanners' "Listening for …" line) now
  scale up through months instead of capping at minutes, showing the two largest
  relevant units.

### Fixes
- Fixed ghosting in native screen transitions: routed pages now paint opaque so
  a pushed screen cleanly covers the one beneath, and detail screens slide in
  with the covered page parallaxing out on the native iOS curve.
- Front-end assets are now served with `Cache-Control: no-cache`, so upgrades no
  longer leave the browser (and service worker) serving stale icons and images;
  unchanged files still return a cheap 304.
- The Android app label is now "OOTT" rather than the placeholder, so the
  notification-permission dialog reads correctly.

### Internal
- New `push_relay/` service: a TypeScript Firebase Cloud Function exposing
  `POST /v1/push` (FCM `sendEach` with per-token status mapping and dead-token
  pruning), a `/health` liveness route, payload validation, and per-IP rate
  limiting, with Jest tests and setup docs.
- Backend gains a `push_tokens` migration, model and data layer, `PUT`/`DELETE
  /api/push_tokens` endpoints, a `GET /api/config` endpoint exposing the
  notification method, and a relay-backed "push" sender — all wired into the
  router and OpenAPI.
- Android package renamed to `net.oottsecurity.app`; Firebase is configured from
  a committed `firebase_options.dart`, and iOS gains the `aps-environment`
  entitlement and remote-notification background mode.
- Dev shell adds `nodejs_22`, `firebase-tools`, and `google-cloud-sdk` for
  building and deploying the relay.
- Refreshed frontend and backend dependency lockfiles within existing version
  ranges (e.g. tokio 1.49 → 1.52.3).
- Documented the Codemagic webhook prerequisite so tag pushes actually trigger
  builds.

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
