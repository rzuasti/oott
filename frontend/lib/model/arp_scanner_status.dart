class ArpScannerStatus {
  final bool isRunning;
  final double? runningForSeconds;
  final double? nextRunInSeconds;

  const ArpScannerStatus({
    required this.isRunning,
    this.runningForSeconds,
    this.nextRunInSeconds,
  });

  factory ArpScannerStatus.fromJson(Map<String, dynamic> json) {
    return ArpScannerStatus(
      isRunning: json['is_running'] as bool,
      runningForSeconds: (json['running_for_seconds'] as num?)?.toDouble(),
      nextRunInSeconds: (json['next_run_in_seconds'] as num?)?.toDouble(),
    );
  }
}
