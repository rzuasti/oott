import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/home/notification_card.dart';
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
        (server) => server.reply(
          200,
          pagedListJson([
            notificationJson(id: 1, title: 'First', body: 'First body'),
            notificationJson(id: 2, title: 'Second', body: 'Second body'),
          ]),
        ),
        queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
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

    // The 400px-wide viewport above is a phone, so the list uses the smaller
    // phone page size of 4. A total of 8 spans two pages.
    List<Map<String, dynamic>> page(int firstId) => List.generate(
      4,
      (i) => notificationJson(id: firstId + i, title: 'Item ${firstId + i}'),
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(page(1), totalCount: 8)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 4},
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(page(5), totalCount: 8)),
      queryParameters: {'is_new': true, 'page_offset': 4, 'page_limit': 4},
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

    // Advance a page: the list should jump back to the top, showing page two's
    // first item (id 5).
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Item 5'), findsWidgets);
    expect(position().pixels, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pulling the list down refetches notifications', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // A single reply list whose contents are swapped before the pull, so the
    // same route re-serializes fresh data on the refresh request.
    final items = <Map<String, dynamic>>[
      notificationJson(id: 1, title: 'Before refresh'),
    ];
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(items)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 4},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Before refresh'), findsOneWidget);

    // The next fetch returns fresh data; a pull-down should pick it up.
    items
      ..clear()
      ..add(notificationJson(id: 2, title: 'After refresh'));
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('After refresh'), findsOneWidget);
    expect(find.textContaining('Before refresh'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swiping a "New" notification marks it read and removes it', (
    tester,
  ) async {
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson([
          notificationJson(id: 1, title: 'First'),
          notificationJson(id: 2, title: 'Second'),
        ]),
      ),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet('/notifications/1', (server) => server.reply(200, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationCard), findsNWidgets(2));

    // Swipe the first card right-to-left (endToStart) to mark it read; it then
    // animates out and the second card takes its place. Pump in steps rather
    // than pumpAndSettle: confirmDismiss awaits the (mocked) backend call, and
    // pumpAndSettle would treat that async gap as settled and return early.
    await tester.fling(
      find.byType(Dismissible).first,
      const Offset(-600, 0),
      1000,
    );
    for (
      var i = 0;
      i < 40 && find.textContaining('First').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.textContaining('First'), findsNothing);
    expect(find.textContaining('Second'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a newly fetched notification flashes in at the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final items = <Map<String, dynamic>>[
      notificationJson(id: 1, title: 'Existing'),
    ];
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(items)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 4},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Existing'), findsOneWidget);

    // A new notification arrives at the top on the next pull-to-refresh.
    items.insert(0, notificationJson(id: 2, title: 'Arrived'));
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    // Pump in small steps until the new card has been inserted and is flashing
    // (the refresh indicator takes a moment to fire before the insert begins).
    var flashing = const Iterable<NotificationCard>.empty();
    for (var i = 0; i < 60 && flashing.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      flashing = tester
          .widgetList<NotificationCard>(find.byType(NotificationCard))
          .where((c) => c.flash);
    }

    // Only the freshly arrived card runs its arrival highlight.
    expect(flashing.length, 1);
    expect(flashing.single.item.title, 'Arrived');

    await tester.pumpAndSettle();
    expect(find.textContaining('Arrived'), findsOneWidget);
    expect(find.textContaining('Existing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a notification dropped by the backend is removed on refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final items = <Map<String, dynamic>>[
      notificationJson(id: 1, title: 'Stays'),
      notificationJson(id: 2, title: 'Vanishes'),
    ];
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(items)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 4},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Vanishes'), findsOneWidget);

    // The second notification is gone from the backend on the next refresh.
    items.removeWhere((j) => j['id'] == 2);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Vanishes'), findsNothing);
    expect(find.textContaining('Stays'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('marking read under the "All" filter keeps the item in place', (
    tester,
  ) async {
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson([notificationJson(id: 1, title: 'Kept')]),
      ),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson([notificationJson(id: 1, title: 'Kept')]),
      ),
      queryParameters: {'is_new': '', 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet('/notifications/1', (server) => server.reply(200, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to the All filter, where read items stay in the list.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kept'), findsOneWidget);

    // Expand the card and mark it read in place.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    // The item stays, now flipped to "old" (offering to mark it unread).
    expect(find.textContaining('Kept'), findsOneWidget);
    expect(find.text('Mark as unread'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing the filter resets the list to the new dataset', (
    tester,
  ) async {
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson([notificationJson(id: 1, title: 'New one')]),
      ),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson([
          notificationJson(id: 2, title: 'Old one', isNew: false),
        ]),
      ),
      queryParameters: {'is_new': false, 'page_offset': 0, 'page_limit': 5},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('New one'), findsOneWidget);

    await tester.tap(find.text('Old'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Old one'), findsOneWidget);
    expect(find.textContaining('New one'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the last-page button jumps to the final page', (tester) async {
    // Wide default surface → page size 5. A total of 12 spans three pages.
    List<Map<String, dynamic>> page(int firstId, int count) => List.generate(
      count,
      (i) => notificationJson(id: firstId + i, title: 'Item ${firstId + i}'),
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(page(1, 5), totalCount: 12)),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet(
      '/notifications',
      (server) => server.reply(200, pagedListJson(page(11, 2), totalCount: 12)),
      queryParameters: {'is_new': true, 'page_offset': 10, 'page_limit': 5},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Last page'));
    await tester.pumpAndSettle();

    expect(find.text('Page 3 of 3'), findsOneWidget);
    expect(find.textContaining('Item 11'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('marking read under "New" decrements the page total', (
    tester,
  ) async {
    // Wide default surface → page size 5. A total of 11 spans three pages;
    // dropping one locally should leave ten, i.e. two pages.
    adapter.onGet(
      '/notifications',
      (server) => server.reply(
        200,
        pagedListJson(
          List.generate(
            5,
            (i) => notificationJson(id: i + 1, title: 'Item ${i + 1}'),
          ),
          totalCount: 11,
        ),
      ),
      queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 5},
    );
    adapter.onGet('/notifications/1', (server) => server.reply(200, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(body: NotificationsList()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 3'), findsOneWidget);

    // Mark the first item read; under "New" it leaves the list and the total
    // drops by one without a re-fetch.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
