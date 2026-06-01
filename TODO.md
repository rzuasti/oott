# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart

## Backend

- [x] Add the scanner that triggered the event to the device_events table
- [x] Improve notifications layout/text
- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it
- [ ] Add uPNP scanner
- [ ] Add DHCP scanner

## Frontend

- [ ] In the notifications list, modify the behavior so that you can fully see the text of the notification before navigating to the device details
- [ ] Can we add front-end tests?
- [x] In the devices list, add a color dot to reflect the last seen status (less than 10 minutes green, otherwise grey)
- [x] Change the URI for the homepage from /notifications to /home
- [x] In the devices list, the order by name is not consistent (iPad... before Lutron when ordering by name descending, maybe it should be case insensitive)
- [x] In the devices list, when the width is "medium", the list looks bad. Maybe make status pills not wrap to new lines
- [x] The ARP scanner status change the yellow to gray (yellow conveys problems, the scanner is just waiting)

## Improve engine

Several complementary approaches work well alongside ARP:

Passive (low noise, no probing):
- SSDP/UPnP — similar but for smart devices/IoT; multicast on 239.255.255.250:1900
- DHCP snooping — monitor DHCP DISCOVER/REQUEST packets; new devices must ask for an IP before doing anything else, so this catches them very early
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- ICMP ping sweep — ping every host in the subnet range; more universal than ARP but generates traffic
- TCP/UDP SYN scan — probe common ports (22, 80, 443, etc.); finds devices that silently drop ICMP
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6

Via infrastructure:
- SNMP query to router/switch — pull the router's ARP table or switch MAC table directly; no need to scan at all
