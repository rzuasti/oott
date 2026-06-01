import 'package:flutter/material.dart';
import 'package:frontend/about/about.dart';
import 'package:frontend/settings/settings.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'devices/device_detail.dart';
import 'devices/device_list.dart';
import 'home/home_screen.dart';
import 'status/status_screen.dart';
import 'utils/pref_utils.dart';
import 'widgets/offline_banner.dart';

// M3 window size class breakpoints
const _mediumBreakpoint = 600.0;
const _expandedBreakpoint = 840.0;

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

        if (width < _mediumBreakpoint) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: child,
                  ),
                ),
              ],
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
          appBar: _buildAppBar(context),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  extended: width >= _expandedBreakpoint,
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
                  child: Column(
                    children: [
                      const OfflineBanner(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
