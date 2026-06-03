import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/device_event.dart';

import '../helpers/fixtures.dart';

void main() {
  test('DeviceEvent.fromJson maps all fields', () {
    final event = DeviceEvent.fromJson(
      deviceEventJson(
        id: 42,
        macAddress: '11:22:33:44:55:66',
        createdOn: '2026-05-20T10:30:00Z',
        eventType: 'changed',
        ipv4Address: '10.0.0.9',
        vendor: 'Initech',
        scanner: 'Ssdp',
      ),
    );

    expect(event.id, 42);
    expect(event.macAddress, '11:22:33:44:55:66');
    expect(event.createdOn, DateTime.parse('2026-05-20T10:30:00Z'));
    expect(event.eventType, 'changed');
    expect(event.ipv4Address, '10.0.0.9');
    expect(event.vendor, 'Initech');
    expect(event.scanner, 'Ssdp');
  });

  test('scannerLabel humanises known scanner names', () {
    expect(_label('Arp'), 'ARP');
    expect(_label('Mdns'), 'mDNS');
    expect(_label('Ssdp'), 'SSDP/UPnP');
    expect(_label('Dhcp'), 'DHCP');
    expect(_label('Snmp'), 'SNMP');
  });

  test('scannerLabel passes through unknown scanner names', () {
    expect(_label('Custom'), 'Custom');
  });
}

String _label(String scanner) =>
    DeviceEvent.fromJson(deviceEventJson(scanner: scanner)).scannerLabel;
