import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/filter_selector.dart';

Widget _harness({
  required Size size,
  required String selected,
  required ValueChanged<String> onSelected,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: FilterSelector<String>(
          values: const ['New', 'Old', 'All'],
          selected: selected,
          labelOf: (v) => v,
          onSelected: onSelected,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('wide layout shows segmented pills and reports selection', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      _harness(
        size: const Size(900, 600),
        selected: 'New',
        onSelected: (v) => picked = v,
      ),
    );

    // All three options are visible as segments at once.
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    await tester.tap(find.text('Old'));
    expect(picked, 'Old');
  });

  testWidgets('narrow layout collapses to a dropdown button', (tester) async {
    String? picked;
    await tester.pumpWidget(
      _harness(
        size: const Size(400, 600),
        selected: 'New',
        onSelected: (v) => picked = v,
      ),
    );

    // Collapsed: no segmented pills, a single button showing the selection.
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);

    // Opening the menu reveals the options; picking one reports it.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);

    await tester.tap(find.text('Old'));
    await tester.pumpAndSettle();
    expect(picked, 'Old');
  });
}
