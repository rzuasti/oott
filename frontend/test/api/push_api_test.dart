import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  test('registerPushToken PUTs the token and platform', () async {
    adapter.onPut(
      '/push_tokens',
      (server) => server.reply(200, null),
      data: {'token': 'fcm-token-123', 'platform': 'android'},
    );

    await BackendAPI.instance.registerPushToken('fcm-token-123', 'android');
  });

  test('unregisterPushToken DELETEs the encoded token path', () async {
    // A token can contain characters that must be percent-encoded in the path.
    adapter.onDelete(
      '/push_tokens/tok%2Fwith%3Aspecial',
      (server) => server.reply(200, null),
    );

    await BackendAPI.instance.unregisterPushToken('tok/with:special');
  });
}
