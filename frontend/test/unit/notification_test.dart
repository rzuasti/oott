import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/notification.dart';
import 'package:frontend/model/notification_type.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Notification.fromJson', () {
    test('maps all fields', () {
      final notification = Notification.fromJson(
        notificationJson(
          id: 9,
          createdOn: '2026-05-15T09:00:00Z',
          notificationType: 'deviceChanged',
          title: 'Device changed',
          body: 'Something changed',
          isNew: false,
          macAddress: '11:22:33:44:55:66',
        ),
      );

      expect(notification.id, 9);
      expect(notification.createdOn, DateTime.parse('2026-05-15T09:00:00Z'));
      expect(notification.notificationType, NotificationType.deviceChanged);
      expect(notification.title, 'Device changed');
      expect(notification.body, 'Something changed');
      expect(notification.isNew, isFalse);
      expect(notification.macAddress, '11:22:33:44:55:66');
    });

    test('leaves macAddress null when absent', () {
      final notification = Notification.fromJson(
        notificationJson(macAddress: null),
      );
      expect(notification.macAddress, isNull);
    });
  });

  test('toJson round-trips back through fromJson', () {
    final original = Notification.fromJson(notificationJson(id: 3));
    final restored = Notification.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.body, original.body);
    expect(restored.isNew, original.isNew);
    expect(restored.notificationType, original.notificationType);
    expect(restored.createdOn, original.createdOn);
    expect(restored.macAddress, original.macAddress);
  });

  test('copyWith only overrides isNew', () {
    final original = Notification.fromJson(notificationJson(isNew: true));
    final updated = original.copyWith(isNew: false);

    expect(updated.isNew, isFalse);
    expect(updated.id, original.id);
    expect(updated.title, original.title);
    expect(original.isNew, isTrue, reason: 'original is not mutated');
  });
}
