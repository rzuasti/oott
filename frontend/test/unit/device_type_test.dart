import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/device_type.dart';

void main() {
  test('fromString parses every snake_case API name', () {
    expect(DeviceType.fromString('phone'), DeviceType.phone);
    expect(
      DeviceType.fromString('network_appliance'),
      DeviceType.networkAppliance,
    );
    expect(DeviceType.fromString('home_security'), DeviceType.homeSecurity);
    expect(DeviceType.fromString('home_appliance'), DeviceType.homeAppliance);
    expect(DeviceType.fromString('gaming_console'), DeviceType.gamingConsole);
  });

  test('fromString is case-insensitive', () {
    expect(DeviceType.fromString('TV'), DeviceType.tv);
  });

  test('fromString falls back to unknown', () {
    expect(DeviceType.fromString('toaster'), DeviceType.unknown);
  });

  test('apiName mirrors the snake_case backend identifiers', () {
    expect(DeviceType.networkAppliance.apiName, 'network_appliance');
    expect(DeviceType.gamingConsole.apiName, 'gaming_console');
    expect(DeviceType.phone.apiName, 'phone');
  });

  test('apiName round-trips through fromString', () {
    for (final type in DeviceType.values) {
      if (type == DeviceType.unknown) continue;
      expect(DeviceType.fromString(type.apiName), type);
    }
  });

  test('label special-cases acronyms', () {
    expect(DeviceType.tv.label, 'TV');
    expect(DeviceType.pc.label, 'PC');
    expect(DeviceType.networkAppliance.label, 'Network Appliance');
  });
}
