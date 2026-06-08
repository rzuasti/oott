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
    adapter.onGet(
      '/config',
      (server) => server.reply(200, {
        'notifications': {'method': 'none'},
      }),
    );
    await PrefUtil.setValue('base_url', 'http://my.server/api');
    await PrefUtil.setValue('api_key', XOR().xorEncode('topsecret'));
  });

  // Opens the dialog from the settings screen via the Re-configure button.
  Future<void> openDialog(WidgetTester tester) async {
    await pumpScreen(tester, const Settings());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.widgetWithText(TextButton, 'Re-configure'));
    await tester.pumpAndSettle();
  }

  testWidgets('prefills the dialog from stored preferences', (tester) async {
    await openDialog(tester);

    expect(find.text('Backend configuration'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'http://my.server/api'),
      findsOneWidget,
    );
  });

  testWidgets('validates an empty base URL when testing the connection', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Test'));
    await tester.pump();

    expect(find.text('The URL cannot be empty'), findsOneWidget);
  });

  testWidgets('editing the connection re-gates Save behind a Test', (
    tester,
  ) async {
    await openDialog(tester);
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
    expect(
      find.textContaining('Test the connection before saving'),
      findsOneWidget,
    );
  });

  testWidgets('saving the prefilled configuration persists and closes', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    // Settle the dialog's exit transition so it has fully left the tree.
    await tester.pumpAndSettle();

    expect(find.text('Settings saved successfully'), findsOneWidget);
    expect(find.text('Backend configuration'), findsNothing);
    expect(PrefUtil.getValue('base_url', ''), 'http://my.server/api');
    // Unmount so the SnackBar's auto-dismiss timer doesn't leak.
    await tearDownTree(tester);
  });

  testWidgets('cancelling discards edits without persisting', (tester) async {
    await openDialog(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'http://changed/api',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Backend configuration'), findsNothing);
    expect(PrefUtil.getValue('base_url', ''), 'http://my.server/api');
  });

  testWidgets('first run auto-opens a non-dismissible dialog', (tester) async {
    await PrefUtil.setValue('base_url', '');
    await pumpScreen(tester, const Settings());
    // Let the post-frame callback open the dialog.
    await tester.pumpAndSettle();

    expect(find.text('Backend configuration'), findsOneWidget);
    // No Cancel on first run; the user must save a working configuration.
    expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });
}
