import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/settings/settings.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  setUp(() async {
    await setUpBackendForTest(
      prefs: {
        'base_url': 'http://my.server/api',
        'api_key': XOR().xorEncode('topsecret'),
        'theme': 'catppuccin_mocha',
      },
    );
  });

  testWidgets('prefills the form from stored preferences', (tester) async {
    await pumpScreen(tester, const Settings());

    expect(find.text('http://my.server/api'), findsOneWidget);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
  });

  testWidgets('validates an empty base URL when testing the connection',
      (tester) async {
    await pumpScreen(tester, const Settings());

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Test'));
    await tester.pump();

    expect(find.text('The URL cannot be empty'), findsOneWidget);
  });

  testWidgets('disables Save once the connection details are edited',
      (tester) async {
    await pumpScreen(tester, const Settings());
    final saveButton = find.widgetWithText(ElevatedButton, 'Save');

    expect(
      tester.widget<ElevatedButton>(saveButton).onPressed,
      isNotNull,
      reason: 'enabled for the unmodified, prefilled form',
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'http://changed/api',
    );
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(saveButton).onPressed,
      isNull,
      reason: 'disabled until the new connection is tested',
    );
  });

  testWidgets('saving the unmodified form shows a success message',
      (tester) async {
    await pumpScreen(tester, const Settings());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await pumpUntilFound(tester, find.text('Settings saved successfully'));

    expect(find.text('Settings saved successfully'), findsOneWidget);
  });
}
