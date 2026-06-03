# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart
- [x] Review and document the release process
- [ ] Add support for push notifications to the app (iOS and Android)
- [x] Review the README.md file

## Backend

- [x] Add configuration options to enable/disable each scanner
- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it
- [x] Add "devices seen on last scan" to the ARP and SNMP scanners status
- [x] Modify the passive scanners status to count devices seen in the last hour
- [x] Simplify the code of scanners (repeated logic)
- [x] Modify the event management to ignore duplicate events if they happen within a time threshold
- [x] Review the recommended timings for the ARP scanner (change defaults) — SNMP defaults set to 10m/5s

## Frontend

- [x] Can we add front-end tests?
- [x] Break down oott_api.dart in modules

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6

Via infrastructure:
- [x] SNMP query to router/firewall — pull the ARP table directly via SNMPv2c (no local probing); see `[snmp_scanner]` config
- Extend the SNMP scanner: SNMPv3 support, and switch MAC/forwarding table (port/VLAN) polling
