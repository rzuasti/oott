# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart

## Backend

- [x] Add Swagger and API docs (OpenAPI)
- [x] Record an activity log in the database
  - [x] One event for each device appearance
- [x] Add date filter to device event list method (from)
- [ ] Add a data set (json) to store maps from vendors -> device type; modify the device creation so that it uses it automatically

## Frontend

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
- [ ] Style app title like favicon (font Barlow Condensed in a pill format with "primary" background)
- [ ] Change the unkown device icon (maybe just a question mark)
- [ ] Scan process monitor and summary page
  - [ ] Is the scan process running
  - [ ] Last run (when, how long did it take, how many devices did it found)
  - [ ] When is the next run
- [ ] Rework notifications page into a homepage for the app
  - [ ] Notifications list
  - [ ] Summary of devices recorded (how many in total, how many seen in the last day, how many not seen for a week)
  - [ ] Scanning process summary (is it running, when will it run again)
- [ ] About page
