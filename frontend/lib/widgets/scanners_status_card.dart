import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/active_scanner_status.dart';
import '../model/passive_scanner_status.dart';
import '../navigation.dart';
import '../theme/app_colors.dart';
import '../utils/backend_reachability.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/periodic_rebuild.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';
import '../theme/dimens.dart';
import '../routes.dart';

/// One scanner shown in the combined card: its display name, the polled status,
/// and how to turn the current value into a (colour, one-line text) summary.
class _Scanner {
  final String name;
  final PolledValue polled;
  final (Color, String) Function(BuildContext, PolledFreshness) resolve;

  const _Scanner(this.name, this.polled, this.resolve);
}

class ScannersStatusCard extends StatefulWidget {
  const ScannersStatusCard({super.key});

  @override
  State<ScannersStatusCard> createState() => _ScannersStatusCardState();
}

class _ScannersStatusCardState extends State<ScannersStatusCard>
    with
        RouteAware,
        WidgetsBindingObserver,
        PeriodicRebuild<ScannersStatusCard> {
  late final List<_Scanner> _scanners;

  PolledValue<T> _poll<T>(
    Future<T> Function({CancelToken? cancelToken}) fetch,
  ) => PolledValue<T>(
    fetch: fetch,
    pollInterval: const Duration(seconds: 5),
    staleErrorAfter: const Duration(seconds: 30),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final api = BackendAPI.instance;
    final arp = _poll(api.getArpScannerStatus);
    final mdns = _poll(api.getMdnsScannerStatus);
    final ssdp = _poll(api.getSsdpScannerStatus);
    final dhcp = _poll(api.getDhcpScannerStatus);
    final snmp = _poll(api.getSnmpScannerStatus);
    _scanners = [
      _Scanner('ARP', arp, (c, f) => _resolve(c, arp, f, _activeStatus)),
      _Scanner('mDNS', mdns, (c, f) => _resolve(c, mdns, f, _passiveStatus)),
      _Scanner(
        'SSDP/UPnP',
        ssdp,
        (c, f) => _resolve(c, ssdp, f, _passiveStatus),
      ),
      _Scanner('DHCP', dhcp, (c, f) => _resolve(c, dhcp, f, _passiveStatus)),
      _Scanner('SNMP', snmp, (c, f) => _resolve(c, snmp, f, _activeStatus)),
    ];
    startRebuildTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _pausePolling();
  }

  @override
  void didPopNext() {
    _resumePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      _resumePolling();
    }
  }

  void _pausePolling() {
    for (final scanner in _scanners) {
      scanner.polled.pause();
    }
    stopRebuildTicker();
  }

  void _resumePolling() {
    for (final scanner in _scanners) {
      scanner.polled.resume();
    }
    startRebuildTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    for (final scanner in _scanners) {
      scanner.polled.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ..._scanners.map((s) => s.polled),
        BackendReachability.instance,
      ]),
      builder: (context, _) {
        final freshness = {
          for (final scanner in _scanners)
            scanner: effectiveFreshness(scanner.polled),
        };
        if (freshness.values.any((f) => f == PolledFreshness.initialLoading)) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(Insets.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(Routes.status),
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanners',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Insets.md),
                  for (var i = 0; i < _scanners.length; i++) ...[
                    if (i > 0) const SizedBox(height: Insets.sm),
                    _scannerRow(
                      context,
                      _scanners[i],
                      freshness[_scanners[i]]!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scannerRow(
    BuildContext context,
    _Scanner scanner,
    PolledFreshness freshness,
  ) {
    final (color, statusText) = scanner.resolve(context, freshness);
    Widget dot = Icon(Icons.circle, color: color, size: 12);
    if (freshness == PolledFreshness.error) {
      dot = Tooltip(
        message: scanner.polled.lastErrorMessage ?? 'Error',
        child: dot,
      );
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(scanner.name, style: Theme.of(context).textTheme.bodyMedium),
              if (freshness == PolledFreshness.stale) ...[
                const SizedBox(width: 6),
                PolledStaleIndicator(polled: scanner.polled),
              ],
            ],
          ),
        ),
        const SizedBox(width: Insets.sm),
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Wraps the shape-specific [compute] with the shared error handling and
  /// elapsed-time calculation common to every scanner row.
  (Color, String) _resolve<T>(
    BuildContext context,
    PolledValue<T> polled,
    PolledFreshness freshness,
    (Color, String) Function(BuildContext, T, double) compute,
  ) {
    if (freshness == PolledFreshness.error) {
      return (Theme.of(context).colorScheme.error, 'Error');
    }
    final elapsed = DateTime.now()
        .difference(polled.lastSuccessAt!)
        .inSeconds
        .toDouble();
    return compute(context, polled.value as T, elapsed);
  }

  (Color, String) _activeStatus(
    BuildContext context,
    ActiveScannerStatus status,
    double elapsed,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (status.isRunning) {
      final secs = (status.runningForSeconds ?? 0) + elapsed;
      return (successColor, 'Running for ${formatSeconds(secs)}');
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (neutralColor, 'Next run in ${formatSeconds(remaining)}');
    }
    return (neutralColor, 'Not started');
  }

  (Color, String) _passiveStatus(
    BuildContext context,
    PassiveScannerStatus status,
    double elapsed,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (status.isListening) {
      if (status.lastDeviceSeenSecondsAgo != null) {
        final secs = status.lastDeviceSeenSecondsAgo! + elapsed;
        return (successColor, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (successColor, 'No devices seen yet');
    }
    return (neutralColor, 'Not started');
  }
}
