import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/theme/catppuccin_mocha_theme.dart';
import 'package:provider/provider.dart';

/// Pumps a single screen/widget under test inside the minimal scaffolding the
/// app's widgets expect: an [AppState] provider (read by Settings) and a
/// [MaterialApp] carrying a real app theme. The real theme is required because
/// several widgets read `Theme.of(context).extension<AppColorExtension>()!`
/// non-null and would crash under a bare [ThemeData].
///
/// Widgets are pumped directly (never through the router shell) so the AppBar's
/// Google Fonts lookup is never reached.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(900, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        theme: catppuccinMochaDarkTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Pumps frames (advancing fake time in small steps) until [finder] matches or
/// [maxFrames] is reached. Needed because Dio resolves each request through an
/// internal zero-duration timer, so the response only lands once the fake clock
/// is advanced — `pumpAndSettle` is unusable here as the polling widgets keep a
/// periodic timer alive forever.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
  Duration step = const Duration(milliseconds: 10),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  if (finder.evaluate().isEmpty) {
    fail('Timed out waiting for $finder');
  }
}

/// Unmounts the widget tree so widgets' `dispose()` cancel their timers and the
/// test ends without "pending timer" failures. Call at the end of widget tests
/// that exercise polling widgets.
Future<void> tearDownTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());
