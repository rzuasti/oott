import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:frontend/about/about.dart';
import 'package:frontend/settings/settings.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'devices/device_detail.dart';
import 'devices/device_list.dart';
import 'home/home_screen.dart';
import 'status/status_screen.dart';
import 'theme/dimens.dart';
import 'utils/pref_utils.dart';
import 'widgets/offline_banner.dart';
import 'widgets/pagination_progress.dart';
import 'routes.dart';

// A navigation entry. Most entries point to an in-app [route]; an entry with a
// null route is an external link (see [externalUrl]) that opens in a new tab and
// is never marked as selected. [wideOnly] entries appear solely in the wide-mode
// navigation rail, not in the compact bottom navigation bar.
typedef _NavDest = ({
  IconData icon,
  IconData activeIcon,
  String label,
  String? route,
  String? externalUrl,
  bool wideOnly,
});

const List<_NavDest> _destinations = [
  (
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
    route: Routes.home,
    externalUrl: null,
    wideOnly: false,
  ),
  (
    icon: Icons.devices_other_outlined,
    activeIcon: Icons.devices_other,
    label: 'Devices',
    route: Routes.devices,
    externalUrl: null,
    wideOnly: false,
  ),
  (
    icon: Icons.monitor_heart_outlined,
    activeIcon: Icons.monitor_heart,
    label: 'Status',
    route: Routes.status,
    externalUrl: null,
    wideOnly: false,
  ),
  (
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
    route: Routes.settings,
    externalUrl: null,
    wideOnly: false,
  ),
  (
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
    label: 'API Docs',
    route: null,
    externalUrl: Routes.apiDocs,
    wideOnly: true,
  ),
  (
    icon: Icons.info_outline,
    activeIcon: Icons.info,
    label: 'About',
    route: Routes.about,
    externalUrl: null,
    wideOnly: false,
  ),
];

// The compact bottom navigation bar omits wide-only entries (e.g. API Docs).
final List<_NavDest> _barDestinations = _destinations
    .where((d) => !d.wideOnly)
    .toList();

// Observer used to notify subscribed routes when another route is pushed
// on top of or popped from them, so they can refresh stale data.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// Routes definitions
final GoRouter router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    ShellRoute(
      observers: [routeObserver],
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: Routes.home,
          name: 'home',
          pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),
          redirect: (context, state) => _redirectToSettings(),
        ),
        GoRoute(
          path: Routes.devices,
          name: 'devices',
          pageBuilder: (context, state) => _fadePage(state, const DeviceList()),
          redirect: (context, state) => _redirectToSettings(),
          routes: [
            GoRoute(
              path: Routes.deviceDetailSegment,
              name: 'deviceDetail',
              // A genuine forward drill-in: slide the detail screen in over the
              // list (see [_drillInPage]).
              pageBuilder: (context, state) {
                final mac = state.pathParameters['macAddress']!;
                return _drillInPage(state, DeviceDetail(macAddress: mac));
              },
            ),
          ],
        ),
        GoRoute(
          path: Routes.status,
          name: 'status',
          pageBuilder: (context, state) =>
              _fadePage(state, const StatusScreen()),
          redirect: (context, state) => _redirectToSettings(),
        ),
        GoRoute(
          path: Routes.settings,
          name: 'settings',
          pageBuilder: (context, state) => _fadePage(state, Settings()),
        ),
        GoRoute(
          path: Routes.about,
          name: 'about',
          pageBuilder: (context, state) => _fadePage(state, const About()),
        ),
      ],
    ),
  ],
);

// Duration of the crossfade between top-level destinations.
const Duration _kTabFadeDuration = Duration(milliseconds: 200);

// Duration of the drill-in slide between a list and a detail screen. Governs the
// whole movement: a pushed route's animation also drives the underlying route's
// secondary animation, so the incoming and outgoing screens stay in lockstep.
const Duration _kDrillInDuration = Duration(milliseconds: 350);

// Routed screens are transparent fragments painted into the shell's single
// [Scaffold]. That is fine for a crossfade, but a screen *pushed on top* (e.g.
// the device detail) must be opaque, otherwise the screen beneath shows straight
// through it as it slides in ("ghosting"). Painting the theme surface behind
// every routed page makes pushes cover cleanly.
Widget _opaque(BuildContext context, Widget child) =>
    ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);

// Page used when switching between top-level destinations (the tabs). Switching
// peers via [context.go] is a replace, not a forward push, so the default iOS
// slide is wrong here: it slides the incoming screen in over the outgoing one,
// leaving the old screen visible underneath. A crossfade animates both screens
// together (each driven by its own primary animation), so nothing is left
// stranded in the background.
//
// When a detail screen is pushed on top of one of these pages (see
// [_drillInPage]) this page's *secondary* animation runs, so it also
// parallax-slides out to the leading edge with the native iOS curve, moving in
// lockstep with the incoming screen instead of sitting stranded behind it. A
// completed primary animation keeps the page in place during this; the slide is
// contributed entirely by the secondary animation.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: _kTabFadeDuration,
    reverseTransitionDuration: _kTabFadeDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation,
          child: CupertinoPageTransition(
            primaryRouteAnimation: kAlwaysCompleteAnimation,
            secondaryRouteAnimation: secondaryAnimation,
            linearTransition: false,
            child: _opaque(context, child),
          ),
        ),
    child: child,
  );
}

// Page used to drill into a detail screen. Slides the incoming screen in from
// the trailing edge with the native iOS curve; the screen left behind is
// parallaxed out by the same route animation via its own secondary transition
// (see [_fadePage]), so both move together. The child is painted opaque so it
// fully covers the screen beneath while sliding.
CustomTransitionPage<void> _drillInPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: _kDrillInDuration,
    reverseTransitionDuration: _kDrillInDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: false,
          child: _opaque(context, child),
        ),
    child: child,
  );
}

// Preference key controlling whether the wide-mode navigation rail shows
// labels (extended) or collapses to an icons-only compact view.
const String _kNavRailExtendedPref = 'nav_rail_extended';

// Fixed rail widths (M3 NavigationRail defaults), set explicitly so the
// collapse/expand toggle can be positioned exactly within the rail.
const double _kRailCompactWidth = 80;
const double _kRailExtendedWidth = 256;

// Application shell and navigation
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // User preference: when on a wide screen, keep the rail extended (labels) or
  // collapse it to icons only to reclaim horizontal space. Defaults to true so
  // existing installs keep the labelled rail they had before.
  bool _navRailExtended =
      PrefUtil.getValue(_kNavRailExtendedPref, true) as bool;

  void _toggleNavRailExtended() {
    setState(() => _navRailExtended = !_navRailExtended);
    PrefUtil.setValue(_kNavRailExtendedPref, _navRailExtended);
  }

  @override
  Widget build(BuildContext context) {
    // The shell gets its own ScaffoldMessenger so its Scaffold does not also
    // render snackbars: those are shown through the top-level messenger in
    // main.dart (rootMessengerKey), which paints above dialogs.
    return ScaffoldMessenger(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectedIndex = _selectedIndex(_destinations, context);
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
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex(_barDestinations, context),
                onDestinationSelected: (index) =>
                    _onDestinationSelected(_barDestinations[index], context),
                destinations: _barDestinations
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

          final mediaPadding = MediaQuery.paddingOf(context);
          return Scaffold(
            appBar: _buildAppBar(context, selectedIndex),
            // The body is a Stack so the collapse/expand toggle can be positioned
            // freely within the rail (the rail's own slots give it an unbounded
            // width, which prevents reliable horizontal alignment).
            body: Stack(
              children: [
                Row(
                  children: [
                    SafeArea(
                      child: NavigationRail(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        minWidth: _kRailCompactWidth,
                        minExtendedWidth: _kRailExtendedWidth,
                        extended:
                            width >= Breakpoints.expanded && _navRailExtended,
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
                            _onDestinationSelected(
                              _destinations[index],
                              context,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        // The overlay pins the pagination progress bar flush
                        // against the very bottom of the content region (the
                        // screen bottom).
                        child: PaginationProgressOverlay(
                          child: Column(
                            children: [
                              const OfflineBanner(),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(Insets.lg),
                                  child: widget.child,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // The collapse/expand toggle, pinned to the bottom of the rail.
                // It sits centred like the other icons when the rail is compact
                // and slides to the rail's right side when it is extended. The
                // double chevron points the way the rail will move: inward («) to
                // collapse, outward (») to expand.
                if (width >= Breakpoints.expanded)
                  AnimatedPositioned(
                    // Match the rail's own extend/collapse animation so the toggle
                    // slides with the edge instead of jumping after it settles.
                    duration: kThemeAnimationDuration,
                    curve: Curves.easeInOut,
                    bottom: mediaPadding.bottom + Insets.md,
                    left: _navRailExtended
                        ? mediaPadding.left +
                              _kRailExtendedWidth -
                              kMinInteractiveDimension -
                              Insets.sm
                        : mediaPadding.left +
                              (_kRailCompactWidth - kMinInteractiveDimension) /
                                  2,
                    child: IconButton(
                      icon: Icon(
                        _navRailExtended
                            ? Icons.keyboard_double_arrow_left
                            : Icons.keyboard_double_arrow_right,
                      ),
                      tooltip: _navRailExtended
                          ? 'Collapse menu'
                          : 'Expand menu',
                      onPressed: _toggleNavRailExtended,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
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

// Index of the [destinations] entry matching the current location, defaulting to
// the first entry (Home). External-link entries have no route and never match.
int _selectedIndex(List<_NavDest> destinations, BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  for (var i = 0; i < destinations.length; i++) {
    final route = destinations[i].route;
    if (route == null) continue;
    if (route == Routes.home) {
      if (location == Routes.home) return i;
    } else if (location.startsWith(route)) {
      return i;
    }
  }
  return 0;
}

void _onDestinationSelected(_NavDest destination, BuildContext context) {
  final route = destination.route;
  if (route != null) {
    context.go(route);
  } else if (destination.externalUrl != null) {
    _openExternal(destination.externalUrl!);
  }
}

// Opens an external link in a new tab. Origin-relative paths (e.g. the API docs)
// resolve against the current host, since the backend serves both the front-end
// and the API docs from the same origin.
// Resolves an external link against [base] (defaulting to the current page).
// Origin-relative paths (e.g. "/api/docs") gain the current scheme and host so
// the resulting URI is launchable; absolute URLs are returned unchanged.
// Without this, launching a scheme-less URI fails when the app is served from
// the backend (e.g. Docker).
Uri resolveExternalUri(String url, {Uri? base}) =>
    (base ?? Uri.base).resolve(url);

Future<void> _openExternal(String url) async {
  final uri = resolveExternalUri(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
