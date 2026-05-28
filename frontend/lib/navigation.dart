import 'package:flutter/material.dart';
import 'package:frontend/about/about.dart';
import 'package:frontend/settings/settings.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'devices/device_detail.dart';
import 'devices/device_list.dart';
import 'notifications/notification_list.dart';
import 'status/status_screen.dart';
import 'utils/pref_utils.dart';

// Routes definitions
final GoRouter router = GoRouter(
  // If there is no API base URL send the user to settings
  initialLocation: '/notifications',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => NotificationList(),
          redirect: (context, state) => _redirectToSettings(),
        ),
        GoRoute(
          path: '/devices',
          name: 'devices',
          builder: (context, state) => const DeviceList(),
          redirect: (context, state) => _redirectToSettings(),
          routes: [
            GoRoute(
              path: ':macAddress',
              name: 'deviceDetail',
              builder: (context, state) {
                final mac = state.pathParameters['macAddress']!;
                return DeviceDetail(macAddress: mac);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/status',
          name: 'status',
          builder: (context, state) => const StatusScreen(),
          redirect: (context, state) => _redirectToSettings(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => Settings(),
        ),
        GoRoute(
          path: '/about',
          name: 'about',
          builder: (context, state) => const About(),
        ),
      ],
    ),
  ],
);

// Application shell and navigation
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'OOTT',
                style: GoogleFonts.barlowCondensed(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
            ),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
          ),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: Text('Notifications'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.devices_other_outlined),
                      selectedIcon: Icon(Icons.devices_other),
                      label: Text('Devices'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.monitor_heart_outlined),
                      selectedIcon: Icon(Icons.monitor_heart),
                      label: Text('Status'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.info_outline),
                      selectedIcon: Icon(Icons.info),
                      label: Text('About'),
                    ),
                  ],
                  selectedIndex: _calculateSelectedIndex(context),
                  onDestinationSelected: (index) =>
                      _onDestinationSelected(index, context),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.surface,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _redirectToSettings() {
  return (PrefUtil.getValue("base_url", "") as String == "")
      ? '/settings'
      : null;
}

int _calculateSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location.startsWith('/notifications')) return 0;
  if (location.startsWith('/devices')) return 1;
  if (location.startsWith('/status')) return 2;
  if (location.startsWith('/settings')) return 3;
  if (location.startsWith('/about')) return 4;
  return 0;
}

void _onDestinationSelected(int index, BuildContext context) {
  switch (index) {
    case 0:
      context.go('/notifications');
      break;
    case 1:
      context.go('/devices');
      break;
    case 2:
      context.go('/status');
      break;
    case 3:
      context.go('/settings');
      break;
    case 4:
      context.go('/about');
      break;
  }
}
