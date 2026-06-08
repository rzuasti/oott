# OOTT ToDo list

- [ ] Add support for push notifications to the app (iOS and Android)

## Release plan for 0.2.0
- [x] Test Android UI on emulator
- [x] Release 0.1.0
- [x] Fix bugs and release 0.1.1
- [x] Install in test server (docker) following documented process
- [x] Install test app on iPhone
- [ ] Test in-house for 1 week
- [ ] Implement push notifications
- [ ] Release 0.2.0
- [ ] Install in test server and test app on iPhone
- [ ] Test in-house for 3 days
- [ ] Release 0.2.1 (or as many versions as needed)
- [ ] Publish website
- [ ] Post on reddit

## Backend

- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it
- [ ] Check for potential dependency upgrades

## Frontend

- [ ] In the status screen, the "listening for" property of passive scanners should change to days and months (now its always minutes)
- [ ] Check for potential dependency upgrades
- [ ] In settings, figure out automatic save

## Push relay

- [ ] Add NPM to the devShell to be able to run tests

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6
