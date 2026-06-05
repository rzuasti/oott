# OOTT ToDo list

- [ ] Add support for push notifications to the app (iOS and Android)
- [ ] README.md - Add section about securing access (reverse proxy, never expose to the internet, etc.)
- [ ] README.md - Simplify storage section (remove the calculations - just leave the results)

## Release plan for 0.2.0
- [ ] Test Android UI on emulator
- [ ] Release 0.1.0
- [ ] Install in test server (docker) following documented process
- [ ] Install test app on iPhone
- [ ] Test in-house for 1 week
- [ ] Implement push notifications
- [ ] Release 0.2.0
- [ ] Install in test server and test app on iPhone
- [ ] Test in-house for 3 days
- [ ] Release 0.2.1 (or as many versions as needed)
- [ ] Publish website
- [ ] Post on reddit

## Backend

- [ ] In the active scanners status, it should count the number of distinct devices it saw on the last scan (avoid duplicates)
- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it

## Frontend

- [ ] Review the whole codebase for dead code, duplication and simplicity
- [x] In the devices list, add an order by type (in the wide version it should be over the icon on the left of the list)
- [ ] How expensive it is to get the total number of pages and implement a go to last page
- [x] Mobile - Device details - Chart buttons not fully visible, replace with combo only for narrow devices

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6
