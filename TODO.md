# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart

## Backend

- [x] Add Swagger and API docs (OpenAPI)
- [ ] Record an activity log in the database
  - [ ] One event for each device appearance

## Frontend

- [x] List recorded devices
- [x] Register a device
- [x] Forget a device
- [x] Extract the snack bar confirmations as a utility widget so it can be reused
- [x] Add a detail device page with access from notifications and devices lists
- [x] Extract the device type as an enum (idem Notification) and with Icon getter too
- [x] Extract the confirmForget and showRegisterDialog methods from both device pages
- [x] In the devices list add filters by owner and device type
- [ ] View detailed log of device activity (based on event log in the backend)
- [ ] Scan process monitor and summary page
  - [ ] Is the scan process running
  - [ ] Last run (when, how long did it take, how many devices did it found)
  - [ ] When is the next run
- [ ] Rework notifications page into a homepage for the app
  - [ ] Notifications list
  - [ ] Summary of devices recorded (how many in total, how many seen in the last day, how many not seen for a week)
  - [ ] Scanning process summary (is it running, when will it run again)
- [ ] About page
