import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/gruvbox_theme.dart';
import 'package:frontend/widgets/pagination_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: gruvboxDarkTheme,
    home: Scaffold(body: child),
  );

  testWidgets('disables every navigation button while loading', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 1,
          hasNextPage: true,
          isLoading: true,
          onPageChanged: (page) => changedTo = page,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Previous page'));
    await tester.tap(find.byTooltip('First page'));
    expect(changedTo, -1);
  });

  testWidgets('enables navigation when idle', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 1,
          hasNextPage: true,
          isLoading: false,
          onPageChanged: (page) => changedTo = page,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Next page'));
    expect(changedTo, 2);

    await tester.tap(find.byTooltip('Previous page'));
    expect(changedTo, 0);
  });
}
