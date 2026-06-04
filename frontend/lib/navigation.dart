import 'package:flutter/material.dart';
import 'package:frontend/about/about.dart';
import 'package:frontend/settings/settings.dart';
import 'package:go_router/go_router.dart';
import 'devices/device_detail.dart';
import 'devices/device_list.dart';
import 'home/home_screen.dart';
import 'status/status_screen.dart';
import 'theme/dimens.dart';
import 'utils/pref_utils.dart';
import 'widgets/offline_banner.dart';
import 'widgets/pagination_progress.dart';

typedef _NavDest = ({IconData icon, IconData activeIcon, String label});

const List<_NavDest> _destinations = [
  (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  (
    icon: Icons.devices_other_outlined,
    activeIcon: Icons.devices_other,
    label: 'Devices',
  ),
  (
    icon: Icons.monitor_heart_outlined,
    activeIcon: Icons.monitor_heart,
    label: 'Status',
  ),
  (
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
  (icon: Icons.info_outline, activeIcon: Icons.info, label: 'About'),
];

// Observer used to notify subscribed routes when another route is pushed
// on top of or popped from them, so they can refresh stale data.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// Routes definitions
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      observers: [routeObserver],
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
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
        final selectedIndex = _calculateSelectedIndex(context);
        final width = constraints.maxWidth;

        if (width < Breakpoints.medium) {
          return Scaffold(
            appBar: _buildAppBar(context, selectedIndex),
            // The overlay pins the pagination progress bar flush against the
            // bottom of the body, i.e. the top of the navigation bar below.
            body: PaginationProgressOverlay(
              child: Column(
                children: [
                  const OfflineBanner(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(index, context),
              destinations: _destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.activeIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(context, selectedIndex),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  extended: width >= Breakpoints.expanded,
                  destinations: _destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.activeIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      _onDestinationSelected(index, context),
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  // The overlay pins the pagination progress bar flush against
                  // the very bottom of the content region (the screen bottom).
                  child: PaginationProgressOverlay(
                    child: Column(
                      children: [
                        const OfflineBanner(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, int selectedIndex) {
    final theme = Theme.of(context);
    return AppBar(
      titleSpacing: Insets.lg,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'OOTT',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              _destinations[selectedIndex].label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
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
  if (location == '/') return 0;
  if (location.startsWith('/devices')) return 1;
  if (location.startsWith('/status')) return 2;
  if (location.startsWith('/settings')) return 3;
  if (location.startsWith('/about')) return 4;
  return 0;
}

void _onDestinationSelected(int index, BuildContext context) {
  switch (index) {
    case 0:
      context.go('/');
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
