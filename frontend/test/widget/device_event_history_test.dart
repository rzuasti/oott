import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/devices/device_event_history.dart';
import 'package:frontend/model/device.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;
  const mac = 'aa:bb:cc:dd:ee:ff';

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  Device device() => Device.fromJson(deviceJson(macAddress: mac));

  testWidgets('renders the chart for events of every type', (tester) async {
    adapter.onGet(
      '/devices/$mac/events',
      (server) => server.reply(200, [
        deviceEventJson(id: 1, eventType: 'NewDevice'),
        deviceEventJson(id: 2, eventType: 'DeviceSeen'),
        deviceEventJson(id: 3, eventType: 'DeviceChanged'),
        deviceEventJson(id: 4, eventType: 'DeviceBackOnline'),
      ]),
      // The widget always sends a (dynamic, now-relative) created_from filter.
      queryParameters: {'created_from': Matchers.any},
    );

    await pumpScreen(tester, DeviceEventHistory(device: device()));
    await pumpUntilFound(tester, find.byType(ScatterChart));

    expect(find.byType(ScatterChart), findsOneWidget);
    expect(find.text('No events in this time range'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('shows an empty-state message when there are no events', (
    tester,
  ) async {
    adapter.onGet(
      '/devices/$mac/events',
      (server) => server.reply(200, <dynamic>[]),
      queryParameters: {'created_from': Matchers.any},
    );

    await pumpScreen(tester, DeviceEventHistory(device: device()));
    await pumpUntilFound(tester, find.text('No events in this time range'));

    expect(find.byType(ScatterChart), findsNothing);

    await tearDownTree(tester);
  });
}
