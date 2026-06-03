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

  testWidgets('shows the empty message when there are no devices',
      (tester) async {
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
}
