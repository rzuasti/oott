class DhcpScannerStatus {
  final bool isListening;
  final double? listeningForSeconds;
  final int devicesSeen;
  final double? lastDeviceSeenSecondsAgo;

  const DhcpScannerStatus({
    required this.isListening,
    this.listeningForSeconds,
    required this.devicesSeen,
    this.lastDeviceSeenSecondsAgo,
  });

  factory DhcpScannerStatus.fromJson(Map<String, dynamic> json) {
    return DhcpScannerStatus(
      isListening: json['is_listening'] as bool,
      listeningForSeconds: (json['listening_for_seconds'] as num?)?.toDouble(),
      devicesSeen: (json['devices_seen'] as num).toInt(),
      lastDeviceSeenSecondsAgo: (json['last_device_seen_seconds_ago'] as num?)
          ?.toDouble(),
    );
  }
}
