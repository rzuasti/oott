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
  });

  testWidgets('prefills the form from stored preferences', (tester) async {
    await pumpScreen(tester, const Settings());
    // Let the on-init config request resolve so its timer doesn't leak.
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('http://my.server/api'), findsOneWidget);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
  });

  testWidgets('validates an empty base URL when testing the connection', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Test'));
    await tester.pump();

    expect(find.text('The URL cannot be empty'), findsOneWidget);
  });

  testWidgets('disables Save once the connection details are edited', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());
    final saveButton = find.widgetWithText(FilledButton, 'Save');

    expect(
      tester.widget<FilledButton>(saveButton).onPressed,
      isNotNull,
      reason: 'enabled for the unmodified, prefilled form',
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'http://changed/api',
    );
    await tester.pump();

    expect(
      tester.widget<FilledButton>(saveButton).onPressed,
      isNull,
      reason: 'disabled until the new connection is tested',
    );
  });

  testWidgets('saving the unmodified form shows a success message', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await pumpUntilFound(tester, find.text('Settings saved successfully'));

    expect(find.text('Settings saved successfully'), findsOneWidget);
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

  testWidgets('explains why Save is disabled after editing the connection', (
    tester,
  ) async {
    await pumpScreen(tester, const Settings());

    // Editing the connection requires re-testing before saving.
    await tester.enterText(
      find.byType(TextFormField).first,
      'http://changed/api',
    );
    await tester.pump();

    expect(
      find.textContaining('Test the connection before saving'),
      findsOneWidget,
    );
  });
}
