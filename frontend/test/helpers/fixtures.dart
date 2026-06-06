/// Typed JSON builders mirroring the backend response shapes, so route stubs
/// and model tests stay terse and use the exact snake_case keys the app's
/// `fromJson` constructors read. Every field has a sensible default; override
/// only what a given test cares about.
library;

Map<String, dynamic> deviceJson({
  String macAddress = 'aa:bb:cc:dd:ee:ff',
  String ipv4Address = '192.168.0.10',
  String vendor = 'Acme Corp',
  String lastSeen = '2026-06-01T12:00:00Z',
  bool isRegistered = false,
  String owner = 'alice',
  String deviceType = 'laptop',
  String? name,
}) => {
  'mac_address': macAddress,
  'ipv4_address': ipv4Address,
  'vendor': vendor,
  'last_seen': lastSeen,
  'is_registered': isRegistered,
  'owner': owner,
  'device_type': deviceType,
  'name': name,
};

Map<String, dynamic> deviceSummaryJson({
  int totalRegistered = 0,
  int seenLastDayRegistered = 0,
  int seenLastDayUnregistered = 0,
  int seenLastWeekRegistered = 0,
  int seenLastWeekUnregistered = 0,
}) => {
  'total_registered': totalRegistered,
  'seen_last_day_registered': seenLastDayRegistered,
  'seen_last_day_unregistered': seenLastDayUnregistered,
  'seen_last_week_registered': seenLastWeekRegistered,
  'seen_last_week_unregistered': seenLastWeekUnregistered,
};

Map<String, dynamic> deviceEventJson({
  int id = 1,
  String macAddress = 'aa:bb:cc:dd:ee:ff',
  String createdOn = '2026-06-01T12:00:00Z',
  String eventType = 'DeviceSeen',
  String ipv4Address = '192.168.0.10',
  String vendor = 'Acme Corp',
  String scanner = 'Arp',
}) => {
  'id': id,
  'mac_address': macAddress,
  'created_on': createdOn,
  'event_type': eventType,
  'ipv4_address': ipv4Address,
  'vendor': vendor,
  'scanner': scanner,
};

Map<String, dynamic> notificationJson({
  int id = 1,
  String createdOn = '2026-06-01T12:00:00Z',
  String notificationType = 'newDeviceFound',
  String title = 'New device found',
  String body = 'A new device joined the network',
  bool isNew = true,
  String? macAddress = 'aa:bb:cc:dd:ee:ff',
}) => {
  'id': id,
  'created_on': createdOn,
  'notification_type': notificationType,
  'title': title,
  'body': body,
  'is_new': isNew,
  'mac_address': macAddress,
};

/// Wraps a page of items in the paged-list response shape the list endpoints
/// return: `{items: [...], total_count: N}`. [totalCount] defaults to the page
/// length, so single-page stubs stay terse; pass it to simulate more pages.
Map<String, dynamic> pagedListJson(
  List<Map<String, dynamic>> items, {
  int? totalCount,
}) => {'items': items, 'total_count': totalCount ?? items.length};

/// Shape shared by the ARP and SNMP scanners (run-on-interval scanners).
Map<String, dynamic> intervalScannerJson({
  bool isRunning = false,
  double? runningForSeconds,
  double? nextRunInSeconds,
  int? lastScanDevicesSeen,
  double? lastScanSecondsAgo,
}) => {
  'is_running': isRunning,
  'running_for_seconds': runningForSeconds,
  'next_run_in_seconds': nextRunInSeconds,
  'last_scan_devices_seen': lastScanDevicesSeen,
  'last_scan_seconds_ago': lastScanSecondsAgo,
};

/// Shape shared by the mDNS, SSDP and DHCP scanners (passive listeners).
Map<String, dynamic> listenerScannerJson({
  bool isListening = false,
  double? listeningForSeconds,
  int devicesSeen = 0,
  double? lastDeviceSeenSecondsAgo,
}) => {
  'is_listening': isListening,
  'listening_for_seconds': listeningForSeconds,
  'devices_seen': devicesSeen,
  'last_device_seen_seconds_ago': lastDeviceSeenSecondsAgo,
};
