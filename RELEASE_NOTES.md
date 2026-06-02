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

## v0.1.0 — 2026-06-02

First public release of OOTT — an easy to setup network device discovery and
alert system that notifies you when new or unknown devices join your local area
network.

### Highlights
- Regular network scanning using ARP probes, plus broadcast/multicast scanners.
- Alerts when a new device is found, when a device changes its IP address or
  network interface vendor (by MAC address), and when a device comes back
  online after a configurable offline period.
- Device type inference from MAC vendor data.
- Web front-end (Flutter/Material 3) for configuration and browsing stored data,
  responsive across desktop, tablet and phone, with native iOS and Android apps.
- Rust backend exposing a documented REST API (OpenAPI / Swagger UI) backed by
  SQLite with incremental migrations.

### Installation
- Available as a pre-built Docker image (`rzuasti/oott`) and as a NixOS flake
  module. See the [README](README.md) for deployment and configuration details.
