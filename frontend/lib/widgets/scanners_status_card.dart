import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/arp_scanner_status.dart';
import '../model/dhcp_scanner_status.dart';
import '../model/mdns_scanner_status.dart';
import '../model/snmp_scanner_status.dart';
import '../model/ssdp_scanner_status.dart';
import '../navigation.dart';
import '../theme/app_colors.dart';
import '../utils/backend_reachability.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';

class ScannersStatusCard extends StatefulWidget {
  const ScannersStatusCard({super.key});

  @override
  State<ScannersStatusCard> createState() => _ScannersStatusCardState();
}

class _ScannersStatusCardState extends State<ScannersStatusCard>
    with RouteAware, WidgetsBindingObserver {
  late final PolledValue<ArpScannerStatus> _arp;
  late final PolledValue<MdnsScannerStatus> _mdns;
  late final PolledValue<SsdpScannerStatus> _ssdp;
  late final PolledValue<DhcpScannerStatus> _dhcp;
  late final PolledValue<SnmpScannerStatus> _snmp;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arp = PolledValue<ArpScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getArpScannerStatus(cancelToken: cancelToken),
      pollInterval: const Duration(seconds: 5),
      staleErrorAfter: const Duration(seconds: 30),
    );
    _mdns = PolledValue<MdnsScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getMdnsScannerStatus(cancelToken: cancelToken),
      pollInterval: const Duration(seconds: 5),
      staleErrorAfter: const Duration(seconds: 30),
    );
    _ssdp = PolledValue<SsdpScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getSsdpScannerStatus(cancelToken: cancelToken),
      pollInterval: const Duration(seconds: 5),
      staleErrorAfter: const Duration(seconds: 30),
    );
    _dhcp = PolledValue<DhcpScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getDhcpScannerStatus(cancelToken: cancelToken),
      pollInterval: const Duration(seconds: 5),
      staleErrorAfter: const Duration(seconds: 30),
    );
    _snmp = PolledValue<SnmpScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getSnmpScannerStatus(cancelToken: cancelToken),
      pollInterval: const Duration(seconds: 5),
      staleErrorAfter: const Duration(seconds: 30),
    );
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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
    _arp.pause();
    _mdns.pause();
    _ssdp.pause();
    _dhcp.pause();
    _snmp.pause();
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _resumePolling() {
    _arp.resume();
    _mdns.resume();
    _ssdp.resume();
    _dhcp.resume();
    _snmp.resume();
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _tickTimer?.cancel();
    _arp.dispose();
    _mdns.dispose();
    _ssdp.dispose();
    _dhcp.dispose();
    _snmp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _arp,
        _mdns,
        _ssdp,
        _dhcp,
        _snmp,
        BackendReachability.instance,
      ]),
      builder: (context, _) {
        final arpFreshness = effectiveFreshness(_arp);
        final mdnsFreshness = effectiveFreshness(_mdns);
        final ssdpFreshness = effectiveFreshness(_ssdp);
        final dhcpFreshness = effectiveFreshness(_dhcp);
        final snmpFreshness = effectiveFreshness(_snmp);
        if (arpFreshness == PolledFreshness.initialLoading ||
            mdnsFreshness == PolledFreshness.initialLoading ||
            ssdpFreshness == PolledFreshness.initialLoading ||
            dhcpFreshness == PolledFreshness.initialLoading ||
            snmpFreshness == PolledFreshness.initialLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final (arpColor, arpText) = _resolveArp(context, arpFreshness);
        final (mdnsColor, mdnsText) = _resolveMdns(context, mdnsFreshness);
        final (ssdpColor, ssdpText) = _resolveSsdp(context, ssdpFreshness);
        final (dhcpColor, dhcpText) = _resolveDhcp(context, dhcpFreshness);
        final (snmpColor, snmpText) = _resolveSnmp(context, snmpFreshness);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/status'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanners',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _scannerRow(
                    context,
                    arpColor,
                    'ARP',
                    arpText,
                    _arp,
                    arpFreshness,
                  ),
                  const SizedBox(height: 8),
                  _scannerRow(
                    context,
                    mdnsColor,
                    'mDNS',
                    mdnsText,
                    _mdns,
                    mdnsFreshness,
                  ),
                  const SizedBox(height: 8),
                  _scannerRow(
                    context,
                    ssdpColor,
                    'SSDP/UPnP',
                    ssdpText,
                    _ssdp,
                    ssdpFreshness,
                  ),
                  const SizedBox(height: 8),
                  _scannerRow(
                    context,
                    dhcpColor,
                    'DHCP',
                    dhcpText,
                    _dhcp,
                    dhcpFreshness,
                  ),
                  const SizedBox(height: 8),
                  _scannerRow(
                    context,
                    snmpColor,
                    'SNMP',
                    snmpText,
                    _snmp,
                    snmpFreshness,
                  ),
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
    Color color,
    String name,
    String statusText,
    PolledValue polled,
    PolledFreshness freshness,
  ) {
    Widget dot = Icon(Icons.circle, color: color, size: 12);
    if (freshness == PolledFreshness.error) {
      dot = Tooltip(message: polled.lastErrorMessage ?? 'Error', child: dot);
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
              if (freshness == PolledFreshness.stale) ...[
                const SizedBox(width: 6),
                PolledStaleIndicator(polled: polled),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  (Color, String) _resolveArp(BuildContext context, PolledFreshness freshness) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (freshness == PolledFreshness.error) {
      return (theme.colorScheme.error, 'Error');
    }
    final status = _arp.value!;
    final elapsed = DateTime.now()
        .difference(_arp.lastSuccessAt!)
        .inSeconds
        .toDouble();
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

  (Color, String) _resolveMdns(
    BuildContext context,
    PolledFreshness freshness,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (freshness == PolledFreshness.error) {
      return (theme.colorScheme.error, 'Error');
    }
    final status = _mdns.value!;
    final elapsed = DateTime.now()
        .difference(_mdns.lastSuccessAt!)
        .inSeconds
        .toDouble();
    if (status.isListening) {
      if (status.lastDeviceSeenSecondsAgo != null) {
        final secs = status.lastDeviceSeenSecondsAgo! + elapsed;
        return (successColor, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (successColor, 'No devices seen yet');
    }
    return (neutralColor, 'Not started');
  }

  (Color, String) _resolveSsdp(
    BuildContext context,
    PolledFreshness freshness,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (freshness == PolledFreshness.error) {
      return (theme.colorScheme.error, 'Error');
    }
    final status = _ssdp.value!;
    final elapsed = DateTime.now()
        .difference(_ssdp.lastSuccessAt!)
        .inSeconds
        .toDouble();
    if (status.isListening) {
      if (status.lastDeviceSeenSecondsAgo != null) {
        final secs = status.lastDeviceSeenSecondsAgo! + elapsed;
        return (successColor, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (successColor, 'No devices seen yet');
    }
    return (neutralColor, 'Not started');
  }

  (Color, String) _resolveDhcp(
    BuildContext context,
    PolledFreshness freshness,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (freshness == PolledFreshness.error) {
      return (theme.colorScheme.error, 'Error');
    }
    final status = _dhcp.value!;
    final elapsed = DateTime.now()
        .difference(_dhcp.lastSuccessAt!)
        .inSeconds
        .toDouble();
    if (status.isListening) {
      if (status.lastDeviceSeenSecondsAgo != null) {
        final secs = status.lastDeviceSeenSecondsAgo! + elapsed;
        return (successColor, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (successColor, 'No devices seen yet');
    }
    return (neutralColor, 'Not started');
  }

  (Color, String) _resolveSnmp(
    BuildContext context,
    PolledFreshness freshness,
  ) {
    final theme = Theme.of(context);
    final successColor = theme.extension<AppColorExtension>()!.success;
    final neutralColor = theme.colorScheme.outline;
    if (freshness == PolledFreshness.error) {
      return (theme.colorScheme.error, 'Error');
    }
    final status = _snmp.value!;
    final elapsed = DateTime.now()
        .difference(_snmp.lastSuccessAt!)
        .inSeconds
        .toDouble();
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
}
