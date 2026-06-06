import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  test('markNotificationAsRead GETs the notification path', () async {
    adapter.onGet('/notifications/7', (server) => server.reply(200, null));

    await BackendAPI.instance.markNotificationAsRead(7);
  });

  test('markNotificationAsNew POSTs to mark_as_new', () async {
    adapter.onPost(
      '/notifications/7/mark_as_new',
      (server) => server.reply(200, null),
    );

    await BackendAPI.instance.markNotificationAsNew(7);
  });

  test('markAllNotificationsAsRead POSTs to mark_all_as_old', () async {
    adapter.onPost(
      '/notifications/mark_all_as_old',
      (server) => server.reply(200, null),
    );

    await BackendAPI.instance.markAllNotificationsAsRead();
  });

  test(
    'listNotifications sends is_new + pagination and reports the total',
    () async {
      adapter.onGet(
        '/notifications',
        (server) => server.reply(
          200,
          pagedListJson([
            notificationJson(id: 1),
            notificationJson(id: 2),
          ], totalCount: 9),
        ),
        queryParameters: {'is_new': true, 'page_offset': 0, 'page_limit': 2},
      );

      final result = await BackendAPI.instance.listNotifications(
        true,
        page: 0,
        perPage: 2,
      );

      expect(result.items, hasLength(2));
      expect(result.totalCount, 9);
    },
  );

  test(
    'listNotifications maps a null filter to an empty is_new param',
    () async {
      adapter.onGet(
        '/notifications',
        (server) => server.reply(200, pagedListJson([])),
        queryParameters: {'is_new': '', 'page_offset': 10, 'page_limit': 5},
      );

      final result = await BackendAPI.instance.listNotifications(
        null,
        page: 2,
        perPage: 5,
      );

      expect(result.items, isEmpty);
      expect(result.totalCount, 0);
    },
  );
}
