import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/device.dart';
import 'package:frontend/model/device_type.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Device.fromJson', () {
    test('maps all snake_case fields', () {
      final device = Device.fromJson(
        deviceJson(
          macAddress: '11:22:33:44:55:66',
          ipv4Address: '10.0.0.5',
          vendor: 'Globex',
          lastSeen: '2026-05-30T08:15:00Z',
          isRegistered: true,
          owner: 'bob',
          deviceType: 'network_appliance',
          name: 'Router',
        ),
      );

      expect(device.macAddress, '11:22:33:44:55:66');
      expect(device.ipv4Address, '10.0.0.5');
      expect(device.vendor, 'Globex');
      expect(device.lastSeen, DateTime.parse('2026-05-30T08:15:00Z'));
      expect(device.isRegistered, isTrue);
      expect(device.owner, 'bob');
      expect(device.deviceType, DeviceType.networkAppliance);
      expect(device.name, 'Router');
    });

    test('leaves name null when absent', () {
      final device = Device.fromJson(deviceJson());
      expect(device.name, isNull);
    });

    test('falls back to unknown device type for unrecognised values', () {
      final device = Device.fromJson(deviceJson(deviceType: 'spaceship'));
      expect(device.deviceType, DeviceType.unknown);
    });
  });
}
