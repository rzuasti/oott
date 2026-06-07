import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/navigation.dart';
import 'package:go_router/go_router.dart';

void main() {
  // The app's real [router] is configured so that switching between top-level
  // destinations crossfades (a [CustomTransitionPage]) instead of using the
  // default platform slide, which would otherwise leave the outgoing screen
  // visible behind the incoming one. Drilling into a detail screen uses its own
  // custom page builder (an opaque iOS-style slide), not the default builder.
  List<GoRoute> topLevelRoutes() {
    final shell = router.configuration.routes.single as ShellRoute;
    return shell.routes.cast<GoRoute>();
  }

  GoRoute routeByName(String name) =>
      topLevelRoutes().firstWhere((r) => r.name == name);

  group('navigation transitions', () {
    test('top-level destinations use a page builder (crossfade)', () {
      for (final name in ['home', 'devices', 'status', 'settings', 'about']) {
        final route = routeByName(name);
        expect(
          route.pageBuilder,
          isNotNull,
          reason: '"$name" should crossfade via a custom page builder',
        );
        expect(route.builder, isNull, reason: '"$name" should not also build');
      }
    });

    test('the device detail drill-in uses a custom page builder (slide)', () {
      final devices = routeByName('devices');
      final detail = devices.routes.single as GoRoute;

      expect(detail.name, 'deviceDetail');
      expect(
        detail.pageBuilder,
        isNotNull,
        reason: 'the detail push should use the opaque drill-in slide page',
      );
      expect(detail.builder, isNull, reason: 'the detail should not also build');
    });
  });
}
