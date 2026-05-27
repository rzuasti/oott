class Device {
  final String macAddress;
  final String ipv4Address;
  final String vendor;
  final DateTime lastSeen;
  final bool isRegistered;
  final String owner;
  final String deviceType;

  Device({
    required this.macAddress,
    required this.ipv4Address,
    required this.vendor,
    required this.lastSeen,
    required this.isRegistered,
    required this.owner,
    required this.deviceType,
  });

  Device.fromJson(Map<String, dynamic> json)
    : macAddress = json['mac_address'] as String,
      ipv4Address = json['ipv4_address'] as String,
      vendor = json['vendor'] as String,
      lastSeen = DateTime.parse(json['last_seen'] as String),
      isRegistered = json['is_registered'] as bool,
      owner = json['owner'] as String,
      deviceType = json['device_type'] as String;
}
