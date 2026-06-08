import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/settings/settings.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:frontend/utils/push_service.dart';

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
  setUp(() async {
    await setUpBackendForTest(
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

  testWidgets('shows the push toggle on a supported platform', (tester) async {
    await pumpScreen(tester, Settings(pushService: _FakePushService()));
    expect(find.text(_toggleText), findsOneWidget);
  });

  testWidgets('hides the push toggle when push is unsupported', (tester) async {
    await pumpScreen(
      tester,
      Settings(pushService: _FakePushService(supported: false)),
    );
    expect(find.text(_toggleText), findsNothing);
  });

  testWidgets('enabling push registers and shows a success message', (
    tester,
  ) async {
    final service = _FakePushService(enableResult: true);
    await pumpScreen(tester, Settings(pushService: service));

    await tester.tap(find.byType(SwitchListTile));
    await pumpUntilFound(
      tester,
      find.text('Push notifications enabled on this device'),
    );

    expect(service.enableCalls, 1);
    expect(PrefUtil.getValue('push_enabled', false), isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
  });

  testWidgets('a declined permission leaves the toggle off with an error', (
    tester,
  ) async {
    final service = _FakePushService(enableResult: false);
    await pumpScreen(tester, Settings(pushService: service));

    await tester.tap(find.byType(SwitchListTile));
    await pumpUntilFound(
      tester,
      find.textContaining('Could not enable push'),
    );

    expect(service.enableCalls, 1);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('disabling push unregisters and shows a success message', (
    tester,
  ) async {
    await PrefUtil.setValue('push_enabled', true);
    final service = _FakePushService();
    await pumpScreen(tester, Settings(pushService: service));

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
}
