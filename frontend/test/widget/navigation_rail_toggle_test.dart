import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/navigation.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:go_router/go_router.dart';

import '../helpers/backend_test_harness.dart';

void main() {
  // A bare router whose shell is the real [MainShell]; the route bodies are
  // trivial so the test exercises only the navigation chrome, not the screens.
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home-body')),
        ],
      ),
    ],
  );

  // A plain [ThemeData] (no Google Fonts) keeps the AppBar renderable in tests.
  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(theme: ThemeData(), routerConfig: buildRouter()),
    );
    await tester.pumpAndSettle();
  }

  NavigationRail rail(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail));

  group('wide-mode navigation rail toggle', () {
    setUp(() async {
      await setUpBackendForTest();
    });

    testWidgets('extends by default and shows a collapse action', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1200, 900));

      expect(rail(tester).extended, isTrue);
      expect(find.byTooltip('Collapse menu'), findsOneWidget);
    });

    testWidgets('collapsing switches the rail to icons only and persists', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1200, 900));

      await tester.tap(find.byTooltip('Collapse menu'));
      await tester.pumpAndSettle();

      expect(rail(tester).extended, isFalse);
      expect(find.byTooltip('Expand menu'), findsOneWidget);
      expect(PrefUtil.getValue('nav_rail_extended', true), isFalse);
    });

    testWidgets('honours a previously collapsed preference on launch', (
      tester,
    ) async {
      await PrefUtil.setValue('nav_rail_extended', false);

      await pumpShell(tester, size: const Size(1200, 900));

      expect(rail(tester).extended, isFalse);
      expect(find.byTooltip('Expand menu'), findsOneWidget);
    });

    testWidgets('offers no toggle below the expanded breakpoint', (
      tester,
    ) async {
      // Medium width (>= 600, < 840): rail is compact and the toggle is hidden.
      await pumpShell(tester, size: const Size(700, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(rail(tester).extended, isFalse);
      expect(find.byTooltip('Collapse menu'), findsNothing);
      expect(find.byTooltip('Expand menu'), findsNothing);
    });
  });
}
