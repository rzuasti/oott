# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart

## Backend

- [x] Use first available network interface when not configured
- [x] Add Swagger and API docs (OpenAPI)
- [x] Record an activity log in the database
  - [x] One event for each device appearance
- [x] Add date filter to device event list method (from)
- [x] Add a data set (json) to store maps from vendors -> device type; modify the device creation so that it uses it automatically
- [x] Add an mDNS/Bonjour scanner
- [ ] Extract the select_interface method and interface logic from ARP scanner to a centralized utility file
- [ ] Figure out if we can univocally identify devices that mask their MAC address (like apple)
- [ ] Add the scanner that triggered the event to the device_events table

## Frontend

- [ ] Add pagination to the devices list screen
- [ ] Add the mDNS/Bonjour scanner status to the Status and Home screens
- [x] Change the notifications list so it has explicit paging (not infinite paging)
- [x] List recorded devices
- [x] Register a device
- [x] Forget a device
- [x] Extract the snack bar confirmations as a utility widget so it can be reused
- [x] Add a detail device page with access from notifications and devices lists
- [x] Extract the device type as an enum (idem Notification) and with Icon getter too
- [x] Extract the confirmForget and showRegisterDialog methods from both device pages
- [x] In the devices list add filters by owner and device type
- [x] View detailed log of device activity (based on event log in the backend)
- [x] Use date filter from backend API for device events list
- [x] Use favicon in web frontend
- [x] Style app title like favicon (font Barlow Condensed in a pill format with "primary" background)
- [x] Update the device type management to consider the following list: phone, laptop, tablet, server, tv, printer, network_appliance (router, switch, firewall, etc.), home_security (camera, doorbell, etc.), home_appliance (fridge, dish washer, washer, dryer, etc.), watch, pc, gaming_console, unknown (use when a vendor cannot be clearly identified with any of the device types or a device is of a vendor not in the vendors json file)
- [x] Change the unkown device icon (maybe just a question mark)
- [x] Scan process monitor and summary page
  - [x] Is the scan process running
  - [x] Last run (when, how long did it take, how many devices did it found)
  - [x] When is the next run
- [x] Rework notifications page into a homepage for the app
  - [x] Notifications list
  - [x] Summary of devices recorded (how many in total, how many seen in the last day, how many not seen for a week)
  - [x] Scanning process summary (is it running, when will it run again)
- [x] About page

## Improve engine

Several complementary approaches work well alongside ARP:

Passive (low noise, no probing):
- mDNS/Bonjour listening — devices broadcast their presence on 224.0.0.251:5353; catches Apple, Android, Chromecast, printers, etc. automatically
- SSDP/UPnP — similar but for smart devices/IoT; multicast on 239.255.255.250:1900
- DHCP snooping — monitor DHCP DISCOVER/REQUEST packets; new devices must ask for an IP before doing anything else, so this catches them very early
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- ICMP ping sweep — ping every host in the subnet range; more universal than ARP but generates traffic
- TCP/UDP SYN scan — probe common ports (22, 80, 443, etc.); finds devices that silently drop ICMP
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6

Via infrastructure:
- SNMP query to router/switch — pull the router's ARP table or switch MAC table directly; no need to scan at all

Best bang for the buck: mDNS + DHCP snooping as passive complements to ARP. mDNS is especially good at naming devices (hostname included in the announcement), and DHCP catches devices the moment they connect rather than waiting for an ARP sweep cycle.
