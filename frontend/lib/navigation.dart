import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'notifications/notification_list.dart';

// Routes definitions
final GoRouter router = GoRouter(
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
        ),
        GoRoute(
          path: '/devices',
          name: 'devices',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/about',
          name: 'about',
          builder: (context, state) => const Placeholder(),
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
            title: const Text('OOTT'),
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

int _calculateSelectedIndex(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location.startsWith('/notifications')) return 0;
  if (location.startsWith('/devices')) return 1;
  if (location.startsWith('/settings')) return 2;
  if (location.startsWith('/about')) return 3;
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
      context.go('/settings');
      break;
    case 3:
      context.go('/about');
      break;
  }
}
