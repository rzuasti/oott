import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  test('getConfig GETs /config and decodes the notification method', () async {
    adapter.onGet(
      '/config',
      (server) => server.reply(200, {
        'notifications': {'method': 'push'},
      }),
    );

    final config = await BackendAPI.instance.getConfig();

    expect(config.notificationMethod, 'push');
  });
}
