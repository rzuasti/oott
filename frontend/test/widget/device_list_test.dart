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
      (server) => server.reply(
        200,
        pagedListJson([
          deviceJson(macAddress: '00:00:00:00:00:01', owner: 'alice'),
          deviceJson(macAddress: '00:00:00:00:00:02', owner: 'bob'),
        ]),
      ),
    );

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byType(DeviceRowWide));

    expect(find.byType(DeviceRowWide), findsNWidgets(2));

    await tearDownTree(tester);
  });

  testWidgets('shows the empty message when there are no devices', (
    tester,
  ) async {
    adapter.onGet('/devices', (server) => server.reply(200, pagedListJson([])));

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
    // A total of 11 across two pages of 10, so the pagination bar appears.
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        pagedListJson(
          List.generate(
            10,
            (i) => deviceJson(
              macAddress: '00:00:00:00:00:${i.toString().padLeft(2, '0')}',
            ),
          ),
          totalCount: 11,
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

  testWidgets('tapping the device-type header sorts by device type', (
    tester,
  ) async {
    // Default ordering (last_seen, desc) returns two devices.
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        pagedListJson([
          deviceJson(macAddress: '00:00:00:00:00:01'),
          deviceJson(macAddress: '00:00:00:00:00:02'),
        ]),
      ),
      queryParameters: {
        'is_registered': false,
        'sort_by': 'last_seen',
        'sort_order': 'desc',
        'page_offset': 0,
        'page_limit': 10,
      },
    );
    // Sorting by device type (asc) returns a single, distinguishable device.
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        pagedListJson([deviceJson(macAddress: '00:00:00:00:00:03')]),
      ),
      queryParameters: {
        'is_registered': false,
        'sort_by': 'device_type',
        'sort_order': 'asc',
        'page_offset': 0,
        'page_limit': 10,
      },
    );

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byType(DeviceRowWide));
    expect(find.byType(DeviceRowWide), findsNWidgets(2));

    await tester.tap(find.byTooltip('Sort by device type'));
    for (
      var i = 0;
      i < 40 && find.byType(DeviceRowWide).evaluate().length != 1;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byType(DeviceRowWide), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('the sort sheet offers ordering by device type', (tester) async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, pagedListJson([deviceJson()])),
    );

    // A phone-width viewport so the compact layout with the sort button shows.
    await pumpScreen(tester, const DeviceList(), size: const Size(500, 900));
    await pumpUntilFound(tester, find.byType(DeviceRowCompact));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Device Type'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('pulling the list down refetches devices', (tester) async {
    // A single reply list whose contents are swapped before the pull, so the
    // same route re-serializes fresh data on the refresh request.
    final devices = <Map<String, dynamic>>[
      deviceJson(macAddress: '00:00:00:00:00:01'),
    ];
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, pagedListJson(devices)),
    );

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

  testWidgets('the last-page button jumps to the final page', (tester) async {
    // Wide viewport → page size 10. A total of 25 spans three pages.
    List<Map<String, dynamic>> page(int first, int count) => List.generate(
      count,
      (i) => deviceJson(
        macAddress: '00:00:00:00:00:${(first + i).toString().padLeft(2, '0')}',
      ),
    );
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, pagedListJson(page(0, 10), totalCount: 25)),
      queryParameters: {
        'is_registered': false,
        'sort_by': 'last_seen',
        'sort_order': 'desc',
        'page_offset': 0,
        'page_limit': 10,
      },
    );
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, pagedListJson(page(20, 5), totalCount: 25)),
      queryParameters: {
        'is_registered': false,
        'sort_by': 'last_seen',
        'sort_order': 'desc',
        'page_offset': 20,
        'page_limit': 10,
      },
    );

    // A tall viewport so the full page of rows and the pagination bar are all
    // on screen at once (no scrolling needed to reach the last-page button).
    await pumpScreen(tester, const DeviceList(), size: const Size(900, 2000));
    await pumpUntilFound(tester, find.byType(DeviceRowWide));
    expect(find.text('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Last page'));
    await pumpUntilFound(tester, find.text('Page 3 of 3'));

    expect(find.text('Page 3 of 3'), findsOneWidget);

    await tearDownTree(tester);
  });
}
