import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/gruvbox_theme.dart';
import 'package:frontend/widgets/pagination_progress.dart';

void main() {
  tearDown(() => paginationLoading.value = false);

  testWidgets('shows the bar only while paginationLoading is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(
          body: PaginationProgressOverlay(child: SizedBox.expand()),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);

    paginationLoading.value = true;
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    paginationLoading.value = false;
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('pins the bar flush against the bottom edge', (tester) async {
    paginationLoading.value = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: gruvboxDarkTheme,
        home: const Scaffold(
          body: PaginationProgressOverlay(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    final overlayRect = tester.getRect(find.byType(PaginationProgressOverlay));
    final barRect = tester.getRect(find.byType(LinearProgressIndicator));
    expect(barRect.bottom, overlayRect.bottom);
    expect(barRect.left, overlayRect.left);
    expect(barRect.right, overlayRect.right);
  });
}
