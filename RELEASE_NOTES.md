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
