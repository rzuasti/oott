import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/notification_type.dart';

void main() {
  test('fromString parses known types case-insensitively', () {
    expect(
      NotificationType.fromString('newDeviceFound'),
      NotificationType.newDeviceFound,
    );
    expect(
      NotificationType.fromString('deviceonlineaftertime'),
      NotificationType.deviceOnlineAfterTime,
    );
    expect(
      NotificationType.fromString('DeviceChanged'),
      NotificationType.deviceChanged,
    );
  });

  test('fromString falls back to other', () {
    expect(NotificationType.fromString('whatever'), NotificationType.other);
  });

  test('name round-trips through fromString', () {
    for (final type in NotificationType.values) {
      if (type == NotificationType.other) continue;
      expect(NotificationType.fromString(type.name), type);
    }
  });
}
