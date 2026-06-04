import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/home/notifications_list.dart';
import 'package:frontend/theme/gruvbox_theme.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  testWidgets(
    'marking an expanded "New" notification as read does not expand the next',
    (tester) async {
      adapter.onGet(
        '/notifications',
        (server) => server.reply(200, [
          notificationJson(id: 1, title: 'First', body: 'First body'),
          notificationJson(id: 2, title: 'Second', body: 'Second body'),
        ]),
        queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 6},
      );
      adapter.onGet('/notifications/1', (server) => server.reply(200, null));

      await tester.pumpWidget(
        MaterialApp(
          theme: gruvboxDarkTheme,
          home: const Scaffold(body: NotificationsList()),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the first notification.
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Mark as read'), findsOneWidget);

      // Mark it as read; it disappears from the "New"-filtered list.
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();

      // The first notification is gone and the second stays collapsed: no
      // card is expanded, so no action buttons are showing.
      expect(find.textContaining('First'), findsNothing);
      expect(find.textContaining('Second'), findsWidgets);
      expect(find.text('Mark as read'), findsNothing);

      // Dispose the widget so its polling timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('changing pages scrolls back to the top of the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    List<Map<String, dynamic>> page(int firstId) => List.generate(
      6,
      (i) => notificationJson(id: firstId + i, title: 'Item ${firstId + i}'),
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, page(1)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 6},
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, page(7)),
      queryParameters: {'is_new': true, 'page_offset': 5, 'page_limit': 6},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();

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
    expect(find.textContaining('Item 7'), findsWidgets);
    expect(position().pixels, 0);

    await tester.pumpWidget(const SizedBox());
  });
}
