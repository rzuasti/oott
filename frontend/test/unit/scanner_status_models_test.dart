import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/arp_scanner_status.dart';
import 'package:frontend/model/dhcp_scanner_status.dart';
import 'package:frontend/model/mdns_scanner_status.dart';
import 'package:frontend/model/snmp_scanner_status.dart';
import 'package:frontend/model/ssdp_scanner_status.dart';

import '../helpers/fixtures.dart';

void main() {
  group('interval scanners (ARP, SNMP)', () {
    test('ArpScannerStatus.fromJson maps populated fields', () {
      final status = ArpScannerStatus.fromJson(
        intervalScannerJson(
          isRunning: true,
          runningForSeconds: 12.5,
          nextRunInSeconds: 30,
          lastScanDevicesSeen: 7,
          lastScanSecondsAgo: 5,
        ),
      );

      expect(status.isRunning, isTrue);
      expect(status.runningForSeconds, 12.5);
      expect(status.nextRunInSeconds, 30.0);
      expect(status.lastScanDevicesSeen, 7);
      expect(status.lastScanSecondsAgo, 5.0);
    });

    test('ArpScannerStatus.fromJson tolerates null optionals', () {
      final status = ArpScannerStatus.fromJson(intervalScannerJson());

      expect(status.isRunning, isFalse);
      expect(status.runningForSeconds, isNull);
      expect(status.nextRunInSeconds, isNull);
      expect(status.lastScanDevicesSeen, isNull);
    });

    test('SnmpScannerStatus.fromJson maps fields', () {
      final status = SnmpScannerStatus.fromJson(
        intervalScannerJson(isRunning: true, runningForSeconds: 3),
      );

      expect(status.isRunning, isTrue);
      expect(status.runningForSeconds, 3.0);
    });
  });

  group('listener scanners (mDNS, SSDP, DHCP)', () {
    test('MdnsScannerStatus.fromJson maps populated fields', () {
      final status = MdnsScannerStatus.fromJson(
        listenerScannerJson(
          isListening: true,
          listeningForSeconds: 99.0,
          devicesSeen: 4,
          lastDeviceSeenSecondsAgo: 8,
        ),
      );

      expect(status.isListening, isTrue);
      expect(status.listeningForSeconds, 99.0);
      expect(status.devicesSeen, 4);
      expect(status.lastDeviceSeenSecondsAgo, 8.0);
    });

    test('SsdpScannerStatus.fromJson requires devicesSeen and tolerates nulls',
        () {
      final status = SsdpScannerStatus.fromJson(
        listenerScannerJson(devicesSeen: 0),
      );

      expect(status.isListening, isFalse);
      expect(status.devicesSeen, 0);
      expect(status.listeningForSeconds, isNull);
      expect(status.lastDeviceSeenSecondsAgo, isNull);
    });

    test('DhcpScannerStatus.fromJson maps fields', () {
      final status = DhcpScannerStatus.fromJson(
        listenerScannerJson(isListening: true, devicesSeen: 2),
      );

      expect(status.isListening, isTrue);
      expect(status.devicesSeen, 2);
    });
  });
}
