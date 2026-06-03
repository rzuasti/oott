import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  test('getArpScannerStatus decodes /arp_scanner/status', () async {
    adapter.onGet(
      '/arp_scanner/status',
      (server) => server.reply(
        200,
        intervalScannerJson(isRunning: true, runningForSeconds: 12),
      ),
    );

    final status = await BackendAPI.instance.getArpScannerStatus();

    expect(status.isRunning, isTrue);
    expect(status.runningForSeconds, 12.0);
  });

  test('getSnmpScannerStatus decodes /snmp_scanner/status', () async {
    adapter.onGet(
      '/snmp_scanner/status',
      (server) => server.reply(200, intervalScannerJson(isRunning: false)),
    );

    final status = await BackendAPI.instance.getSnmpScannerStatus();

    expect(status.isRunning, isFalse);
  });

  test('getMdnsScannerStatus decodes /mdns_scanner/status', () async {
    adapter.onGet(
      '/mdns_scanner/status',
      (server) => server.reply(
        200,
        listenerScannerJson(isListening: true, devicesSeen: 3),
      ),
    );

    final status = await BackendAPI.instance.getMdnsScannerStatus();

    expect(status.isListening, isTrue);
    expect(status.devicesSeen, 3);
  });

  test('getSsdpScannerStatus decodes /ssdp_scanner/status', () async {
    adapter.onGet(
      '/ssdp_scanner/status',
      (server) => server.reply(200, listenerScannerJson(devicesSeen: 1)),
    );

    final status = await BackendAPI.instance.getSsdpScannerStatus();

    expect(status.devicesSeen, 1);
  });

  test('getDhcpScannerStatus decodes /dhcp_scanner/status', () async {
    adapter.onGet(
      '/dhcp_scanner/status',
      (server) => server.reply(
        200,
        listenerScannerJson(isListening: true, devicesSeen: 5),
      ),
    );

    final status = await BackendAPI.instance.getDhcpScannerStatus();

    expect(status.isListening, isTrue);
    expect(status.devicesSeen, 5);
  });
}
