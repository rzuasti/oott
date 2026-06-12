import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/devices/device_list.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  Future<void> openRowMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'deleting a not-registered device from the list calls the delete endpoint',
    (tester) async {
      adapter.onGet(
        '/devices',
        (server) => server.reply(
          200,
          pagedListJson([
            deviceJson(macAddress: 'aa:bb:cc:dd:ee:01', isRegistered: false),
          ]),
        ),
      );
      var deleteCalled = false;
      adapter.onDelete('/devices/aa:bb:cc:dd:ee:01/permanently', (server) {
        deleteCalled = true;
        server.reply(200, null);
      });

      await pumpScreen(tester, const DeviceList());
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));

      await openRowMenu(tester);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // The confirmation dialog warns the deletion is permanent.
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(find.text('Device deleted'), findsOneWidget);

      await tearDownTree(tester);
    },
  );

  testWidgets('not-registered devices do not expose Forget', (tester) async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        pagedListJson([
          deviceJson(macAddress: 'aa:bb:cc:dd:ee:02', isRegistered: false),
        ]),
      ),
    );

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));

    await openRowMenu(tester);
    expect(find.text('Forget'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets(
    'forget dialog deletes the device when the also-delete box is ticked',
    (tester) async {
      adapter.onGet(
        '/devices',
        (server) => server.reply(
          200,
          pagedListJson([
            deviceJson(
              macAddress: 'aa:bb:cc:dd:ee:03',
              isRegistered: true,
              owner: 'alice',
            ),
          ]),
        ),
      );
      var deleteCalled = false;
      // Only the permanent-delete route is mocked: had the dialog taken the
      // plain "forget" path instead, the unmocked DELETE would surface an error
      // snackbar rather than the success one asserted below.
      adapter.onDelete('/devices/aa:bb:cc:dd:ee:03/permanently', (server) {
        deleteCalled = true;
        server.reply(200, null);
      });

      await pumpScreen(tester, const DeviceList());
      await pumpUntilFound(tester, find.byIcon(Icons.more_vert));

      await openRowMenu(tester);
      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();

      // Checkbox is unchecked by default, so no warning is shown yet.
      expect(find.textContaining('cannot be undone'), findsNothing);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Ticking it reveals the permanent-deletion warning.
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(find.text('Device deleted'), findsOneWidget);

      await tearDownTree(tester);
    },
  );

  testWidgets('forget dialog unregisters when the box is left unticked', (
    tester,
  ) async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(
        200,
        pagedListJson([
          deviceJson(
            macAddress: 'aa:bb:cc:dd:ee:04',
            isRegistered: true,
            owner: 'bob',
          ),
        ]),
      ),
    );
    var forgetCalled = false;
    adapter.onDelete('/devices/aa:bb:cc:dd:ee:04', (server) {
      forgetCalled = true;
      server.reply(200, null);
    });

    await pumpScreen(tester, const DeviceList());
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));

    await openRowMenu(tester);
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Forget'));
    await tester.pumpAndSettle();

    expect(forgetCalled, isTrue);
    expect(find.text('Device forgotten'), findsOneWidget);

    await tearDownTree(tester);
  });
}
