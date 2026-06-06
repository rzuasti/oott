# OOTT ToDo list

- [ ] Add support for push notifications to the app (iOS and Android)
- [ ] Modify the release script to check that gh is logged in and that frontend tests are run before releasing

## Release plan for 0.2.0
- [x] Test Android UI on emulator
- [x] Release 0.1.0
- [ ] Fix bugs and release 0.1.1
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

- [x] In notifications, when its a new device(s) found notification, remove the status block (new devices are never registered)
- [x] In notifications, when the vendor is empty put (unknown)
- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it

## Frontend

- [x] When the user goes to the / URI in a production server redirect him to /web
- [x] Add a link to the API docs (/api/docs) in the navigation (new window - only visible in wide)

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6
