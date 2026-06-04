import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/empty_state.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  setUp(() async {
    await setUpBackendForTest();
  });

  testWidgets('renders the icon and message without an action button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const EmptyState(
        icon: Icons.devices_other_outlined,
        message: 'No devices found',
      ),
    );

    expect(find.text('No devices found'), findsOneWidget);
    expect(find.byIcon(Icons.devices_other_outlined), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('renders an action button and invokes its callback', (
    tester,
  ) async {
    var tapped = false;
    await pumpScreen(
      tester,
      EmptyState(
        icon: Icons.devices_other_outlined,
        message: 'No devices found',
        actionLabel: 'Check scanner status',
        onAction: () => tapped = true,
      ),
    );

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Check scanner status'),
    );
    expect(tapped, isTrue);
  });
}
