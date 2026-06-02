class ArpScannerStatus {
  final bool isRunning;
  final double? runningForSeconds;
  final double? nextRunInSeconds;
  final int? lastScanDevicesSeen;
  final double? lastScanSecondsAgo;

  const ArpScannerStatus({
    required this.isRunning,
    this.runningForSeconds,
    this.nextRunInSeconds,
    this.lastScanDevicesSeen,
    this.lastScanSecondsAgo,
  });

  factory ArpScannerStatus.fromJson(Map<String, dynamic> json) {
    return ArpScannerStatus(
      isRunning: json['is_running'] as bool,
      runningForSeconds: (json['running_for_seconds'] as num?)?.toDouble(),
      nextRunInSeconds: (json['next_run_in_seconds'] as num?)?.toDouble(),
      lastScanDevicesSeen: (json['last_scan_devices_seen'] as num?)?.toInt(),
      lastScanSecondsAgo: (json['last_scan_seconds_ago'] as num?)?.toDouble(),
    );
  }
}
