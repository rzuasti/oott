import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/status/status_screen.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  void stubAllScanners() {
    adapter.onGet(
      '/arp_scanner/status',
      (server) => server.reply(
        200,
        intervalScannerJson(isRunning: true, runningForSeconds: 10),
      ),
    );
    adapter.onGet(
      '/mdns_scanner/status',
      (server) => server.reply(
        200,
        listenerScannerJson(isListening: true, devicesSeen: 2),
      ),
    );
    adapter.onGet(
      '/ssdp_scanner/status',
      (server) => server.reply(200, listenerScannerJson()),
    );
    adapter.onGet(
      '/dhcp_scanner/status',
      (server) => server.reply(200, listenerScannerJson()),
    );
    adapter.onGet(
      '/snmp_scanner/status',
      (server) => server.reply(200, intervalScannerJson()),
    );
  }

  testWidgets('renders each scanner card with its resolved status', (
    tester,
  ) async {
    stubAllScanners();

    await pumpScreen(tester, const StatusScreen());
    await pumpUntilFound(tester, find.text('Running'));

    // The screen title now lives in the shared shell AppBar, not the body.
    expect(find.text('ARP Scanner'), findsOneWidget);
    expect(find.text('mDNS Scanner'), findsOneWidget);
    expect(find.text('Running'), findsWidgets);
    expect(find.text('Listening'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tearDownTree(tester);
  });
}
