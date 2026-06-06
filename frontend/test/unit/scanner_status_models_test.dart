import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/active_scanner_status.dart';
import 'package:frontend/model/passive_scanner_status.dart';

import '../helpers/fixtures.dart';

void main() {
  group('active scanners (ARP, SNMP)', () {
    test('ActiveScannerStatus.fromJson maps populated fields', () {
      final status = ActiveScannerStatus.fromJson(
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

    test('ActiveScannerStatus.fromJson tolerates null optionals', () {
      final status = ActiveScannerStatus.fromJson(intervalScannerJson());

      expect(status.isRunning, isFalse);
      expect(status.runningForSeconds, isNull);
      expect(status.nextRunInSeconds, isNull);
      expect(status.lastScanDevicesSeen, isNull);
    });
  });

  group('passive scanners (mDNS, SSDP, DHCP)', () {
    test('PassiveScannerStatus.fromJson maps populated fields', () {
      final status = PassiveScannerStatus.fromJson(
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

    test('PassiveScannerStatus.fromJson requires devicesSeen and tolerates '
        'nulls', () {
      final status = PassiveScannerStatus.fromJson(
        listenerScannerJson(devicesSeen: 0),
      );

      expect(status.isListening, isFalse);
      expect(status.devicesSeen, 0);
      expect(status.listeningForSeconds, isNull);
      expect(status.lastDeviceSeenSecondsAgo, isNull);
    });
  });
}
