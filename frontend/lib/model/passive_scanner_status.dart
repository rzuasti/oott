/// Status of a passive scanner (one that listens continuously, e.g. mDNS, SSDP,
/// DHCP). Mirrors the backend's `PassiveSnapshot` / `PassiveScannerStatusResponse`.
class PassiveScannerStatus {
  final bool isListening;
  final double? listeningForSeconds;
  final int devicesSeen;
  final double? lastDeviceSeenSecondsAgo;

  const PassiveScannerStatus({
    required this.isListening,
    this.listeningForSeconds,
    required this.devicesSeen,
    this.lastDeviceSeenSecondsAgo,
  });

  factory PassiveScannerStatus.fromJson(Map<String, dynamic> json) {
    return PassiveScannerStatus(
      isListening: json['is_listening'] as bool,
      listeningForSeconds: (json['listening_for_seconds'] as num?)?.toDouble(),
      devicesSeen: (json['devices_seen'] as num).toInt(),
      lastDeviceSeenSecondsAgo: (json['last_device_seen_seconds_ago'] as num?)
          ?.toDouble(),
    );
  }
}
