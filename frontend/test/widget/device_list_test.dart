import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/devices/device_list.dart';
import 'package:frontend/devices/device_list_rows.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  testWidgets('renders device rows after loading', (tester) async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, [
        deviceJson(macAddress: '00:00:00:00:00:01', owner: 'alice'),
        deviceJson(macAddress: '00:00:00:00:00:02', owner: 'bob'),
      ]),
    );

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byType(DeviceRowWide));

    expect(find.byType(DeviceRowWide), findsNWidgets(2));

    await tearDownTree(tester);
  });

  testWidgets('shows the empty message when there are no devices', (
    tester,
  ) async {
    adapter.onGet('/devices', (server) => server.reply(200, <dynamic>[]));

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.text('No unregistered devices'));

    expect(find.text('No unregistered devices'), findsOneWidget);
    expect(find.byType(DeviceRowWide), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('shows an error message when the request fails', (tester) async {
    adapter.onGet('/devices', (server) => server.reply(500, {'error': 'boom'}));

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(
      tester,
      find.textContaining('Backend error (status 500)'),
    );

    expect(find.textContaining('Backend error (status 500)'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('changing pages scrolls back to the top of the list', (
    tester,
  ) async {
    // 11 devices: a full page of 10 plus one, so the pagination bar appears.
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        List.generate(
          11,
          (i) => deviceJson(
            macAddress: '00:00:00:00:00:${i.toString().padLeft(2, '0')}',
          ),
        ),
      ),
    );

    // A short viewport so the rows overflow the screen and the list can scroll.
    await pumpScreen(tester, const DeviceList(), size: const Size(900, 500));
    await pumpUntilFound(tester, find.byType(DeviceRowWide));

    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollable).position;

    // Scroll down to reveal the pagination bar.
    await tester.drag(scrollable, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(position().pixels, greaterThan(0));

    // Advance a page: the list should jump back to the top.
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(position().pixels, 0);

    await tearDownTree(tester);
  });

  testWidgets('pulling the list down refetches devices', (tester) async {
    // A single reply list whose contents are swapped before the pull, so the
    // same route re-serializes fresh data on the refresh request.
    final devices = <Map<String, dynamic>>[
      deviceJson(macAddress: '00:00:00:00:00:01'),
    ];
    adapter.onGet('/devices', (server) => server.reply(200, devices));

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byType(DeviceRowWide));
    expect(find.byType(DeviceRowWide), findsOneWidget);

    // The next fetch returns an extra device; a pull-down should pick it up.
    devices.add(deviceJson(macAddress: '00:00:00:00:00:02'));
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeviceRowWide), findsNWidgets(2));

    await tearDownTree(tester);
  });
}
