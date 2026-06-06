import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/dimens.dart';
import 'package:frontend/theme/gruvbox_theme.dart';
import 'package:frontend/widgets/pagination_bar.dart';

void main() {
  Widget wrap(Widget child, {Size? size}) => MediaQuery(
    data: MediaQueryData(size: size ?? const Size(1200, 800)),
    child: MaterialApp(
      theme: gruvboxDarkTheme,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('disables every navigation button while loading', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 1,
          totalPages: 3,
          isLoading: true,
          onPageChanged: (page) => changedTo = page,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Previous page'));
    await tester.tap(find.byTooltip('First page'));
    await tester.tap(find.byTooltip('Last page'));
    expect(changedTo, -1);
  });

  testWidgets('enables navigation when idle', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 1,
          totalPages: 3,
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

  testWidgets('last-page button jumps to the final page', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 0,
          totalPages: 5,
          isLoading: false,
          onPageChanged: (page) => changedTo = page,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Last page'));
    expect(changedTo, 4);
  });

  testWidgets('forward buttons disable on the last page', (tester) async {
    var changedTo = -1;
    await tester.pumpWidget(
      wrap(
        PaginationBar(
          currentPage: 4,
          totalPages: 5,
          isLoading: false,
          onPageChanged: (page) => changedTo = page,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Last page'));
    expect(changedTo, -1);
  });

  testWidgets('spells out the page label on wide layouts', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PaginationBar(
          currentPage: 1,
          totalPages: 5,
          isLoading: false,
          onPageChanged: _noop,
        ),
        size: const Size(1200, 800),
      ),
    );

    expect(find.text('Page 2 of 5'), findsOneWidget);
  });

  testWidgets('uses the compact page label on narrow layouts', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PaginationBar(
          currentPage: 1,
          totalPages: 5,
          isLoading: false,
          onPageChanged: _noop,
        ),
        size: Size(Breakpoints.medium - 1, 800),
      ),
    );

    expect(find.text('2 / 5'), findsOneWidget);
  });
}

void _noop(int _) {}
