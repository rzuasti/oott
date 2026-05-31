import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/arp_scanner_status.dart';
import '../model/mdns_scanner_status.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';

class ScannersStatusCard extends StatefulWidget {
  const ScannersStatusCard({super.key});

  @override
  State<ScannersStatusCard> createState() => _ScannersStatusCardState();
}

class _ScannersStatusCardState extends State<ScannersStatusCard> {
  late final PolledValue<ArpScannerStatus> _arp;
  late final PolledValue<MdnsScannerStatus> _mdns;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
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
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _arp.dispose();
    _mdns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_arp, _mdns]),
      builder: (context, _) {
        if (_arp.freshness == PolledFreshness.initialLoading ||
            _mdns.freshness == PolledFreshness.initialLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final (arpColor, arpText) = _resolveArp();
        final (mdnsColor, mdnsText) = _resolveMdns();

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
                    'Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _scannerRow(context, arpColor, 'ARP', arpText, _arp),
                  const SizedBox(height: 8),
                  _scannerRow(context, mdnsColor, 'mDNS', mdnsText, _mdns),
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
  ) {
    Widget dot = Icon(Icons.circle, color: color, size: 12);
    if (polled.freshness == PolledFreshness.error) {
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
              if (polled.freshness == PolledFreshness.stale) ...[
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

  (Color, String) _resolveArp() {
    if (_arp.freshness == PolledFreshness.error) {
      return (Colors.red, 'Error');
    }
    final status = _arp.value!;
    final elapsed = DateTime.now()
        .difference(_arp.lastSuccessAt!)
        .inSeconds
        .toDouble();
    if (status.isRunning) {
      final secs = (status.runningForSeconds ?? 0) + elapsed;
      return (Colors.green, 'Running for ${formatSeconds(secs)}');
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (Colors.amber, 'Next run in ${formatSeconds(remaining)}');
    }
    return (Colors.grey, 'Not yet started');
  }

  (Color, String) _resolveMdns() {
    if (_mdns.freshness == PolledFreshness.error) {
      return (Colors.red, 'Error');
    }
    final status = _mdns.value!;
    final elapsed = DateTime.now()
        .difference(_mdns.lastSuccessAt!)
        .inSeconds
        .toDouble();
    if (status.isListening) {
      if (status.lastDeviceSeenSecondsAgo != null) {
        final secs = status.lastDeviceSeenSecondsAgo! + elapsed;
        return (Colors.green, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (Colors.green, 'No devices seen yet');
    }
    return (Colors.grey, 'Not yet started');
  }
}
