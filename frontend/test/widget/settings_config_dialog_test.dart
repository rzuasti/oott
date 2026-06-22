import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/settings/settings.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

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

  // Locates the error icon inside the Test button (its failure-flash state).
  Finder testButtonErrorIcon() => find.descendant(
    of: find.widgetWithText(FilledButton, 'Test'),
    matching: find.byIcon(Icons.error_outline),
  );

  testWidgets('a failed test flashes the Test button red, then reverts', (
    tester,
  ) async {
    // The test binding fails outbound HTTP, so the connection test fails
    // without any explicit stubbing.
    await openDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Test'));
    // Let the request resolve and the snackbar's entrance animation run.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The button flashes its failure state...
    expect(testButtonErrorIcon(), findsOneWidget);
    // ...and the error snackbar is shown *while the dialog is still open*. (In
    // the real app it renders above the dialog via the top-level messenger; the
    // bare test harness falls back to the page messenger, but co-presence still
    // proves the snackbar fires on failure.)
    expect(find.text('Backend configuration'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    // After the flash duration the button reverts to its idle look.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(testButtonErrorIcon(), findsNothing);
    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'Test'),
        matching: find.byIcon(Icons.play_arrow),
      ),
      findsOneWidget,
    );

    await tearDownTree(tester);
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

  testWidgets('stacks full-size action buttons on a narrow screen', (
    tester,
  ) async {
    // Pump on a narrow phone surface so the three-button action row can't fit.
    await pumpScreen(tester, const Settings(), size: const Size(360, 800));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.widgetWithText(TextButton, 'Re-configure'));
    await tester.pumpAndSettle();

    final testButton = find.widgetWithText(FilledButton, 'Test');
    final saveButton = find.widgetWithText(FilledButton, 'Save');

    // Test on top, Save below it: the buttons are stacked, not squeezed into a
    // single shrunken row.
    expect(
      tester.getTopLeft(testButton).dy,
      lessThan(tester.getTopLeft(saveButton).dy),
    );

    // Each button is laid out at a comfortable, full-size width rather than
    // being scaled down to a tiny sliver.
    expect(tester.getSize(saveButton).width, greaterThan(200));
    expect(tester.getSize(testButton).width, greaterThan(200));
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
