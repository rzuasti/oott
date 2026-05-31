# OOTT ToDo list

- [x] Add linting to CLAUDE.md for both Rust and Dart

## Backend

- [x] Use first available network interface when not configured
- [x] Add Swagger and API docs (OpenAPI)
- [x] Record an activity log in the database
  - [x] One event for each device appearance
- [x] Add date filter to device event list method (from)
- [x] Add a data set (json) to store maps from vendors -> device type; modify the device creation so that it uses it automatically
- [x] Separate the devices "update" method into update and seen (one for API edit one for scanners)
- [ ] Add the scanner that triggered the event to the device_events table
- [ ] Improve notifications layout/text
- [ ] Add uPNP scanner
- [ ] Add DHCP scanner

## Frontend

- [ ] In the devices list, add a color dot to reflect the last seen status (less than 10 minutes green, otherwise grey)
- [ ] Change the URI for the homepage from /notifications to /home
- [ ] In the devices list, the order by name is not consistent (iPad... before Lutron when ordering by name descending, maybe it should be case insensitive)
- [ ] In the devices list, when the width is "medium", the list looks bad. Maybe make status pills not wrap to new lines
- [ ] The ARP scanner status change the yellow to gray (yellow conveys problems, the scanner is just waiting)
- [ ] Implement DIO improvements:

----------------------------------
I read oott_api.dart, callers (device_list.dart, device_actions.dart, notifications_list.dart, scanners_status_card.dart), and ui_snackbars.dart. Here is the review organized by your three areas.

Performance

1. No timeouts configured on Dio (oott_api.dart:29). connectTimeout/receiveTimeout/sendTimeout are unset, so any stalled connection holds the request indefinitely. The 5-second status poll in scanners_status_card.dart:32 can easily pile up in-flight requests when the backend is unreachable. Set ~5s connect / ~10s receive at minimum.
2. No in-flight request coalescing or cancellation. _fetchPage in device_list.dart:76 can be invoked by the owner debounce, sort changes, filter chips, RefreshIndicator, and didPopNext concurrently. There is no CancelToken, so an older response can overwrite a newer one (classic stale-write race). Same in notifications_list.dart:79 where the 1-minute timer can race with user actions. Hold a CancelToken per logical fetch and cancel the previous one before issuing the next.
3. Periodic timers fire while the widget isn't visible. scanners_status_card.dart polls every 5s regardless of route. Pause polls when the screen is off-route (RouteAware) or via WidgetsBindingObserver lifecycle. notifications_list.dart already does RouteAware — good — but its 1-minute timer also keeps ticking when off-route.
4. Singleton built only once at app launch (oott_api.dart:21). _baseUrl and _apiKey are late finals captured from PrefUtil in _internal(). If the user changes the URL/key in Settings, every subsequent call still uses the old Dio. Either expose a reconfigure(baseUrl, apiKey) that rebuilds the Dio, or read prefs through an interceptor on every request.
5. _pageSize = 5 in oott_api.dart:17 is dead code. Every caller passes limit explicitly. Either remove it or make it the actual default by not requiring callers to pass _pageSize + 1. The "+1 to detect a next page" trick is currently duplicated at every call site — fold it into the API method (listDevices(... page, perPage) → returns (items, hasNextPage)).
6. No response caching for frequently-polled status endpoints. If/when multiple widgets show scanner status (or you add more dashboards), each will hit tiny in-memory ValueNotifier/stream perstatus endpoint would let multiple widgets subscribe to one poll.                                      
Resiliency                                                                                             
1. No retry on transient failures. A momentary backend restart bubbles straight to a red "Error" indicadio_smart_retry (or a small custom intercff for idempotent calls only — GETs and the read-marking POSTs are safe; the PUT /devices register/update path needs caller-level idempotency beforetrying.
2. No connectivity awareness. connectivity_plus + a centralized "backend reachable" ValueNotifier lets skip polling while offline, (b) surface a banner instead of every card going redindependently, and (c) auto-resume on reconnect.                                                       3. Status cards drop the last-known-good anners_status_card.dart:63). One missedpoll flips the indicator to red even though the previous value was 4 seconds old. Keep _arpStatus populincrement a "consecutive failures" counteN failures or T seconds — and consider a"stale" tint rather than full error if the prior value is recent.                                      4. Authorization: Bearer <empty> when the yet (oott_api.dart:34). Build the headerconditionally; sending an empty bearer makes the 401 response harder to distinguish from "key wrong."  5. test() uses response.toString().contaiart:55). Parse JSON instead — a backendreverse-proxy that echoes paths in HTML error pages could spuriously match.                            6. No request idempotency keys on PUT /de ever turn on retries you'll want these.
                                                                                                       Error handling
                                                                                                       1. Errors leak raw DioException.toString(.dart:45,160,263 does 'Failed to forgetdevice: $e'. That produces multi-line technical text in the snackbar (URL, headers, status). Build a simapDioErrorToUserMessage(DioException) he
  - 401/403 → "Authentication failed. Check your API key in Settings."                                   - 404 → context-appropriate "not found"
  - 408/connectionTimeout/receiveTimeout → "Backend did not respond."                                    - connectionError/no response → "Cannot
  - 5xx → "Backend error. Please try again."                                                             - else → status code + short message.
2. **Silent error swallow in notifications_list.dart:92** (catch (_)). The user sees the empty-state me items found") as if there were genuinely, show a snackbar; better, surface an_errorfield and render an inline error/retry likedevice_list.dart` does.                               3. Unhandled exceptions on mutation calls_markAllAsRead, line 119/121markNotificationAsRead/AsNew have no try/catch. A backend hiccup throws an unhandled Future error, the snackbar fires anyway, and the UI optimised. Wrap each in try/catch, and either (a)don't update UI until after success, or (b) implement true optimistic update + rollback on failure.    4. Type-cast errors masquerade as generic List / as Map<String, dynamic>(oott_api.dart:130, 191, 200, 207, 214, 236) throws a TypeError if the backend returns an error envelopdifferent shape. These bypass DioExceptioce as raw _TypeError ... strings to theuser. Either generate models from the OpenAPI spec or wrap parsing in try/catch and rethrow as a domainApiException.
5. API key is logged in cleartext (oott_api.dart:27 debugPrint('API KEY: $_apiKey')). debugPrint is a nrelease, but it lands in flutter run logsreplace with ${_apiKey.isEmpty ? "<empty>": "<set>"}.                                                                                            6. Per-method debugPrint('About to call .lace with a single LogInterceptor (wrappedin kDebugMode) — gives you method, URL, status, and timing without 30 lines of debugPrint. Bonus: a cusinterceptor is where the error-mapping, rrefresh concerns belong.
7. Inconsistent error UX across screens. device_list.dart shows a full-screen "Error: ..." (line 238), scanners_status_card.dart shows a tiny reackbars it, notifications_list.dartsilently shows empty. Pick a small set of patterns (transient mutation → snackbar; screen-level load → inline error+retry; background poll → status badpply consistently.

Suggested next steps, in priority order

1. (DONE) Add request timeouts and a DioExceptiol, big UX win).
2. (DONE) Replace the singleton's "captured at construction" config with a reconfigure() method called from Settings on
save.
3. (DONE) Add CancelTokens to the two paginated screens to fix the stale-write race.
4. (DONE) Add a LogInterceptor (debug-only) and ; drop the API key log.
5. (DONE) Centralize the "fetch with last-known-good + N-failures threshold" pattern for status polls.
6. (DONE) Wrap unguarded mutation calls (notificths) in try/catch with user-visiblefailure.
7. Once the above is in, add dio_smart_re
----------------------------------


- [x] Review how we are using DIO and improve error handling (500 error page?)
- [x] Rework the devices list into a list when the screen is wide enough
- [x] Display the device "name" in the list and details
- [x] When registering a device ask for the name
- [x] Add a device edit feature for registered devices
- [x] Add an mDNS/Bonjour scanner
- [x] Extract the select_interface method and interface logic from ARP scanner to a centralized utility file
- [x] Figure out if we can univocally identify devices that mask their MAC address (like apple)
- [x] Add a "go to first" and "go to last" buttons to paginations (notification list for now)
- [x] Replace the ARP scanner widget in the home screen with a Scanning status widget that provides a one liner for each scanner
- [x] Add pagination to the devices list screen - now you can't see all devices
- [x] Add the mDNS/Bonjour scanner status to the Status and Home screens
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
