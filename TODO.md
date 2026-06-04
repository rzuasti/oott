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

- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it

## Frontend

- [x] Mobile - Implement pull to refresh on the notifications and devices list
- [x] Mobile - reduce lists length (# of items) so they fit on a phone in one screen (use iPhone latest gen and Google phone latest gen)
- [x] Mobile - In the devices list the filters and sort buttons overlap (dont fit in the screen)
- [x] When changing pages (either list) the items should change to placeholders while loading
- [x] The notifications list should not refresh coldly every time. It should add/remove notifications with an animation as if a stack
- [x] Make gruvbox the default theme
- [x] Can we add front-end tests?
- [x] Break down oott_api.dart in modules

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6
