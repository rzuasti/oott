/// Type of a recorded device event, mirroring the backend's `DeviceEventType`.
enum DeviceEventType {
  newDevice('NewDevice'),
  deviceSeen('DeviceSeen'),
  deviceChanged('DeviceChanged'),
  deviceBackOnline('DeviceBackOnline');

  const DeviceEventType(this.wireValue);

  /// Value used by the backend API to represent this event type.
  final String wireValue;

  /// Parses a backend wire value, falling back to [deviceSeen] for any
  /// unrecognised value (the non-special case).
  static DeviceEventType fromString(String value) =>
      DeviceEventType.values.firstWhere(
        (type) => type.wireValue == value,
        orElse: () => DeviceEventType.deviceSeen,
      );
}
