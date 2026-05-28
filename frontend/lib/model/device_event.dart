class DeviceEvent {
  final int id;
  final String macAddress;
  final DateTime createdOn;
  final String eventType;
  final String ipv4Address;
  final String vendor;

  const DeviceEvent({
    required this.id,
    required this.macAddress,
    required this.createdOn,
    required this.eventType,
    required this.ipv4Address,
    required this.vendor,
  });

  factory DeviceEvent.fromJson(Map<String, dynamic> json) {
    return DeviceEvent(
      id: json['id'] as int,
      macAddress: json['mac_address'] as String,
      createdOn: DateTime.parse(json['created_on'] as String),
      eventType: json['event_type'] as String,
      ipv4Address: json['ipv4_address'] as String,
      vendor: json['vendor'] as String,
    );
  }
}
