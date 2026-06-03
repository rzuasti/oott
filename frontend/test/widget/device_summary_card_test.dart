import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/device_summary_card.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  testWidgets('shows a loading spinner before the summary arrives',
      (tester) async {
    adapter.onGet(
      '/devices/summary',
      (server) => server.reply(200, deviceSummaryJson()),
    );

    await pumpScreen(tester, const DeviceSummaryCard());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the in-flight request resolve so no Dio timer is left pending.
    await pumpUntilFound(tester, find.byType(Divider));
    await tearDownTree(tester);
  });

  testWidgets('renders the summary numbers after loading', (tester) async {
    adapter.onGet(
      '/devices/summary',
      (server) => server.reply(
        200,
        deviceSummaryJson(totalRegistered: 12, seenLastDayRegistered: 3),
      ),
    );

    await pumpScreen(tester, const DeviceSummaryCard());
    await pumpUntilFound(tester, find.text('12'));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await tearDownTree(tester);
  });

  testWidgets('shows the error message when the request fails', (tester) async {
    adapter.onGet(
      '/devices/summary',
      (server) => server.reply(500, {'error': 'boom'}),
    );

    await pumpScreen(tester, const DeviceSummaryCard());
    await pumpUntilFound(
      tester,
      find.textContaining('Backend error (status 500)'),
    );

    expect(
      find.textContaining('Backend error (status 500)'),
      findsOneWidget,
    );

    await tearDownTree(tester);
  });
}
