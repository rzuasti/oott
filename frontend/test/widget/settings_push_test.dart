import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/settings/settings.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:frontend/utils/push_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

// A fake so the toggle can be exercised without Firebase.
class _FakePushService implements PushService {
  _FakePushService({this.supported = true, this.enableResult = true});

  final bool supported;
  final bool enableResult;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> enable() async {
    enableCalls++;
    return enableResult;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
  }
}

const _toggleText = 'Push notifications on this device';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest(
      prefs: {
        'base_url': 'http://my.server/api',
        'api_key': XOR().xorEncode('topsecret'),
        'theme': 'catppuccin_mocha',
      },
    );
    // The mock SharedPreferences persist across tests in this isolate, so reset
    // the per-device push intent to a known-off baseline before each test.
    await PrefUtil.setValue('push_enabled', false);
  });

  // Stubs the backend config endpoint the settings screen reads on load.
  void stubNotificationMethod(String method) {
    adapter.onGet(
      '/config',
      (server) => server.reply(200, {
        'notifications': {'method': method},
      }),
    );
  }

  // Pumps frames so the async config load (resolved via Dio's zero-duration
  // timer) settles, for assertions that expect the toggle to be absent.
  Future<void> settleConfig(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('shows the push toggle when the backend method is push', (
    tester,
  ) async {
    stubNotificationMethod('push');
    await pumpScreen(tester, Settings(pushService: _FakePushService()));
    await pumpUntilFound(tester, find.text(_toggleText));
    expect(find.text(_toggleText), findsOneWidget);
  });

  testWidgets('hides the push toggle when push is unsupported', (tester) async {
    stubNotificationMethod('push');
    await pumpScreen(
      tester,
      Settings(pushService: _FakePushService(supported: false)),
    );
    await settleConfig(tester);
    expect(find.text(_toggleText), findsNothing);
  });

  testWidgets('hides the push toggle when the backend method is not push', (
    tester,
  ) async {
    stubNotificationMethod('pushover');
    await pumpScreen(tester, Settings(pushService: _FakePushService()));
    await settleConfig(tester);
    expect(find.text(_toggleText), findsNothing);
  });

  testWidgets('enabling push registers and shows a success message', (
    tester,
  ) async {
    stubNotificationMethod('push');
    final service = _FakePushService(enableResult: true);
    await pumpScreen(tester, Settings(pushService: service));
    await pumpUntilFound(tester, find.byType(SwitchListTile));

    await tester.tap(find.byType(SwitchListTile));
    await pumpUntilFound(
      tester,
      find.text('Push notifications enabled on this device'),
    );

    expect(service.enableCalls, 1);
    expect(PrefUtil.getValue('push_enabled', false), isTrue);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('a declined permission leaves the toggle off with an error', (
    tester,
  ) async {
    stubNotificationMethod('push');
    final service = _FakePushService(enableResult: false);
    await pumpScreen(tester, Settings(pushService: service));
    await pumpUntilFound(tester, find.byType(SwitchListTile));

    await tester.tap(find.byType(SwitchListTile));
    await pumpUntilFound(tester, find.textContaining('Could not enable push'));

    expect(service.enableCalls, 1);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('disabling push unregisters and shows a success message', (
    tester,
  ) async {
    stubNotificationMethod('push');
    await PrefUtil.setValue('push_enabled', true);
    final service = _FakePushService();
    await pumpScreen(tester, Settings(pushService: service));
    await pumpUntilFound(tester, find.byType(SwitchListTile));

    // Starts on because the stored intent is enabled.
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.byType(SwitchListTile));
    await pumpUntilFound(
      tester,
      find.text('Push notifications disabled on this device'),
    );

    expect(service.disableCalls, 1);
    expect(PrefUtil.getValue('push_enabled', false), isFalse);
  });

  testWidgets('hides the test button when push is off on this device', (
    tester,
  ) async {
    stubNotificationMethod('push');
    await PrefUtil.setValue('push_enabled', false);
    await pumpScreen(tester, Settings(pushService: _FakePushService()));
    await pumpUntilFound(tester, find.byType(SwitchListTile));

    expect(find.text('Send test notification'), findsNothing);
  });

  testWidgets('sends a test notification when push is on', (tester) async {
    stubNotificationMethod('push');
    adapter.onPost(
      '/notifications/test',
      (server) => server.reply(200, null),
    );
    await PrefUtil.setValue('push_enabled', true);
    await pumpScreen(tester, Settings(pushService: _FakePushService()));
    await pumpUntilFound(tester, find.text('Send test notification'));

    await tester.tap(find.text('Send test notification'));
    await pumpUntilFound(
      tester,
      find.text('Test notification sent. It should arrive shortly.'),
    );
  });
}
