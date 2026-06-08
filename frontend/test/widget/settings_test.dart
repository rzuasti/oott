import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/settings/settings.dart';
import 'package:frontend/utils/pref_utils.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  setUp(() async {
    final adapter = await setUpBackendForTest(
      prefs: {
        'base_url': 'http://my.server/api',
        'api_key': XOR().xorEncode('topsecret'),
        'theme': 'catppuccin_mocha',
      },
    );
    // Settings loads the backend config on init; these tests don't exercise the
    // push toggle, so report a non-push method to keep it hidden.
    adapter.onGet(
      '/config',
      (server) => server.reply(200, {
        'notifications': {'method': 'none'},
      }),
    );
    // The mock SharedPreferences persist across tests in this isolate; restore
    // the configured connection a previous test may have changed.
    await PrefUtil.setValue('base_url', 'http://my.server/api');
    await PrefUtil.setValue('api_key', XOR().xorEncode('topsecret'));
    await PrefUtil.setValue('theme', 'catppuccin_mocha');
  });

  testWidgets('shows the configured connection read-only', (tester) async {
    await pumpScreen(tester, const Settings());
    // Let the on-init config request resolve so its timer doesn't leak.
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('http://my.server/api'), findsOneWidget);
    // The key stays masked until revealed.
    expect(find.text('topsecret'), findsNothing);
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
    // No inline Save button: theme and push apply immediately.
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
  });

  testWidgets('reveals the API key when the visibility toggle is tapped', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(find.text('topsecret'), findsOneWidget);
  });

  testWidgets('changing the theme applies immediately, no save needed', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));

    await tester.tap(find.text('Catppuccin Mocha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruvbox Dark').last);
    await tester.pumpAndSettle();

    expect(PrefUtil.getValue('theme', ''), 'gruvbox_dark');
  });

  testWidgets('opens the backend configuration dialog from Re-configure', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));

    await tester.tap(find.widgetWithText(TextButton, 'Re-configure'));
    await tester.pumpAndSettle();

    expect(find.text('Backend configuration'), findsOneWidget);
    // Prefilled from the stored connection.
    expect(
      find.widgetWithText(TextFormField, 'http://my.server/api'),
      findsOneWidget,
    );
  });

  testWidgets('shows the welcome intro when no server is configured', (
    tester,
  ) async {
    await PrefUtil.setValue('base_url', '');
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('Welcome to OOTT'), findsOneWidget);
  });

  testWidgets('hides the welcome intro once a server is configured', (
    tester,
  ) async {
    await PrefUtil.setValue('base_url', 'http://my.server/api');
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('Welcome to OOTT'), findsNothing);
  });
}
