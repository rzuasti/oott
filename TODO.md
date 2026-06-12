# OOTT ToDo list

- [x] Add support for push notifications to the app (iOS and Android)
- [x] Remove push notifications plan
- [x] Add the capability to delete a device from the system
- [x] Review CLAUDE.md to make it shorter and easier to read for AIs while keeping all its intentions

## Release plan for 0.2.0
- [x] Test Android UI on emulator
- [x] Release 0.1.0
- [x] Fix bugs and release 0.1.1
- [x] Install in test server (docker) following documented process
- [x] Install test app on iPhone
- [x] Test in-house for 1 week
- [x] Implement push notifications
- [x] Release 0.2.0
- [x] Install in test server and test app on iPhone
- [ ] Test in-house for 3 days
- [ ] Test flake install
- [ ] Release 0.2.1 (or as many versions as needed)
- [ ] Publish website
- [ ] Post on reddit

## Backend

- [ ] Implement the pushover API call directly to support HTML content and review notification text to use it
- [x] Check for potential dependency upgrades
- [ ] Upgrade dependencies to new major versions

## Frontend

- [ ] Add more themes (Dracula, Nord, Catppuccin Latte, Gruvbox light)
- [ ] Remove the license and notice from the UI, just link to the github pages
- [ ] In the status screen, change the order of the scanners so that SNMP is second
- [ ] On Android, make the font of the icon (phone screen) bigger
- [x] In the status screen, the "listening for" property of passive scanners should change to days and months (now its always minutes)
- [ ] Upgrade dependencies to new major versions
- [x] Check for potential dependency upgrades
- [x] In the frontend, in the settings screen, move the backend configuration to a popup dialog that asks for the URL and API key and allows the user to test and save it. In the main screen it should present both items as read only and allow the user to change the theme and push notifications and both should trigger the change immediately (ie. without a save button). The dialog for the backend config should be accesible via a "Re-configure" link or button (do what aligns best with M3). The first time the user uses the UI (or when the backend is not configured at all, it should navigate to the settings screen with the dialog open, and upon Saving the backend config it should refresh the settings page)
- [x] The permissions dialog for push notifications on android says "Allow frontend to send you notifications"

## Push relay

- [x] Add NPM to the devShell to be able to run tests

## Improve engine

Passive (low noise, no probing):
- Passive packet capture — observe any broadcast/multicast traffic; a device that never responds to ARP still generates traffic

Active (you probe the network):
- NDP (Neighbor Discovery Protocol) — IPv6 equivalent of ARP; important if the network uses IPv6
