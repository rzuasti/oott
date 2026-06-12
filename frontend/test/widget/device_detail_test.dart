import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/devices/device_detail.dart';
import 'package:frontend/main.dart';
import 'package:frontend/theme/catppuccin_mocha_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:provider/provider.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  // Pumps the device-detail page inside a minimal router so `context.go` has a
  // real GoRouter to navigate with. The `/devices` destination renders a marker
  // we can assert against once a deletion navigates away from the detail page.
  Future<void> pumpDetail(WidgetTester tester, String mac) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/devices/$mac',
      routes: [
        GoRoute(
          path: '/devices',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('DEVICES LIST'))),
        ),
        GoRoute(
          path: '/devices/:mac',
          builder: (_, state) => Scaffold(
            body: DeviceDetail(macAddress: state.pathParameters['mac']!),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp.router(
          theme: catppuccinMochaDarkTheme,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('deleting a not-registered device navigates to the list', (
    tester,
  ) async {
    const mac = 'aa:bb:cc:dd:ee:01';
    adapter.onGet(
      '/devices/$mac',
      (server) =>
          server.reply(200, deviceJson(macAddress: mac, isRegistered: false)),
    );
    adapter.onGet(
      '/devices/$mac/events',
      (server) => server.reply(200, const []),
    );
    var deleteCalled = false;
    adapter.onDelete('/devices/$mac/permanently', (server) {
      deleteCalled = true;
      server.reply(200, null);
    });

    await pumpDetail(tester, mac);
    await pumpUntilFound(tester, find.widgetWithText(TextButton, 'Delete'));

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );

    await pumpUntilFound(tester, find.text('DEVICES LIST'));
    expect(deleteCalled, isTrue);
    expect(find.text('DEVICES LIST'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('forgetting with the delete box ticked navigates to the list', (
    tester,
  ) async {
    const mac = 'aa:bb:cc:dd:ee:02';
    adapter.onGet(
      '/devices/$mac',
      (server) => server.reply(
        200,
        deviceJson(macAddress: mac, isRegistered: true, owner: 'alice'),
      ),
    );
    adapter.onGet(
      '/devices/$mac/events',
      (server) => server.reply(200, const []),
    );
    var deleteCalled = false;
    adapter.onDelete('/devices/$mac/permanently', (server) {
      deleteCalled = true;
      server.reply(200, null);
    });

    await pumpDetail(tester, mac);
    await pumpUntilFound(
      tester,
      find.widgetWithText(TextButton, 'Forget Device'),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Forget Device'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );

    await pumpUntilFound(tester, find.text('DEVICES LIST'));
    expect(deleteCalled, isTrue);
    expect(find.text('DEVICES LIST'), findsOneWidget);

    await tearDownTree(tester);
  });
}
