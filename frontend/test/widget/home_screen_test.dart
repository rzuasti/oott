import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/home/home_screen.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  void stubHomeEndpoints() {
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, [
        notificationJson(id: 1, title: 'New device found'),
      ]),
    );
    adapter.onGet(
      '/devices/summary',
      (server) => server.reply(200, deviceSummaryJson(totalRegistered: 5)),
    );
    adapter.onGet(
      '/arp_scanner/status',
      (server) => server.reply(200, intervalScannerJson(isRunning: true)),
    );
    adapter.onGet(
      '/mdns_scanner/status',
      (server) => server.reply(200, listenerScannerJson(isListening: true)),
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

  testWidgets('shows notifications, the device summary and scanner statuses',
      (tester) async {
    stubHomeEndpoints();

    // Below the 700px breakpoint the home screen uses its single-column layout,
    // giving the cards full width and avoiding the cramped fixed-width side
    // column (whose rows overflow under the test font metrics).
    await pumpScreen(tester, const HomeScreen(), size: const Size(690, 2000));
    await pumpUntilFound(tester, find.textContaining('New device found'));

    expect(find.textContaining('New device found'), findsOneWidget);
    expect(find.text('Registered in the system'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tearDownTree(tester);
  });
}
