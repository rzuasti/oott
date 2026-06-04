import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/home/notification_card.dart';
import 'package:frontend/model/notification.dart' as oott_model;
import 'package:frontend/model/notification_type.dart';
import 'package:frontend/utils/friendly_date_formatter.dart';

oott_model.Notification _sampleNotification() => oott_model.Notification(
  id: 1,
  title: 'New device found',
  body: 'A long body that wraps across multiple lines when expanded.',
  notificationType: NotificationType.newDeviceFound,
  createdOn: DateTime(2026, 6, 4, 12),
  isNew: true,
  macAddress: 'AA:BB:CC:DD:EE:FF',
);

Future<void> _pumpCard(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotificationCard(
          item: _sampleNotification(),
          formatter: FriendlyDateFormatter(),
          onSetRead: (_) async => true,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping the body expands and then collapses the card', (
    tester,
  ) async {
    await _pumpCard(tester);

    // Initially collapsed: no action buttons.
    expect(find.text('Mark as read'), findsNothing);

    // Tap the body to expand.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);

    // Tap directly on the body text to collapse.
    await tester.tap(
      find.text('A long body that wraps across multiple lines when expanded.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsNothing);
  });

  testWidgets('tapping the action area (not a button) collapses the card', (
    tester,
  ) async {
    await _pumpCard(tester);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);

    // Tap the action row outside any button: its left edge is empty space
    // because the buttons are aligned to the end.
    final actions = tester.getRect(find.byType(OverflowBar));
    await tester.tapAt(Offset(actions.left + 1, actions.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsNothing);
  });
}
