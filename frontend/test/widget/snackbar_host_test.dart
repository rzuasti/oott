import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/catppuccin_mocha_theme.dart';
import 'package:frontend/utils/ui_snackbars.dart';

import '../helpers/pump_app.dart';

void main() {
  // Builds an app wired exactly like main.dart: the router/Navigator sits under
  // the snackbar host so snackbars render above dialogs.
  Future<BuildContext> pumpHostedApp(WidgetTester tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: catppuccinMochaDarkTheme,
        builder: buildSnackbarHost,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return pageContext;
  }

  testWidgets('snackbar shows through the host above an open dialog', (
    tester,
  ) async {
    final context = await pumpHostedApp(tester);

    // Open a dialog so a modal barrier is on screen.
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('A dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.text('A dialog'), findsOneWidget);

    UISnackbars.showSuccess(context, 'Hello there');
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('the snackbar close-icon tooltip does not crash for lack of an '
      'overlay', (tester) async {
    final context = await pumpHostedApp(tester);

    UISnackbars.showError(context, 'Boom');
    await tester.pumpAndSettle();

    // Long-pressing the close icon shows its tooltip, which needs an Overlay
    // ancestor — the previous host had none and threw "No Overlay widget found".
    await tester.longPress(find.byIcon(Icons.close));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);

    await tearDownTree(tester);
  });
}
