/// Status of an active scanner (one that runs on an interval, e.g. ARP, SNMP).
/// Mirrors the backend's `ActiveSnapshot` / `ActiveScannerStatusResponse`.
class ActiveScannerStatus {
  final bool isRunning;
  final double? runningForSeconds;
  final double? nextRunInSeconds;
  final int? lastScanDevicesSeen;
  final double? lastScanSecondsAgo;

  const ActiveScannerStatus({
    required this.isRunning,
    this.runningForSeconds,
    this.nextRunInSeconds,
    this.lastScanDevicesSeen,
    this.lastScanSecondsAgo,
  });

  factory ActiveScannerStatus.fromJson(Map<String, dynamic> json) {
    return ActiveScannerStatus(
      isRunning: json['is_running'] as bool,
      runningForSeconds: (json['running_for_seconds'] as num?)?.toDouble(),
      nextRunInSeconds: (json['next_run_in_seconds'] as num?)?.toDouble(),
      lastScanDevicesSeen: (json['last_scan_devices_seen'] as num?)?.toInt(),
      lastScanSecondsAgo: (json['last_scan_seconds_ago'] as num?)?.toDouble(),
    );
  }
}
