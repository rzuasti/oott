import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/arp_scanner_status.dart';
import '../model/mdns_scanner_status.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';

class ScannersStatusCard extends StatefulWidget {
  const ScannersStatusCard({super.key});

  @override
  State<ScannersStatusCard> createState() => _ScannersStatusCardState();
}

class _ScannersStatusCardState extends State<ScannersStatusCard> {
  ArpScannerStatus? _arpStatus;
  String? _arpError;
  MdnsScannerStatus? _mdnsStatus;
  String? _mdnsError;
  DateTime? _statusReceivedAt;
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    ArpScannerStatus? arp;
    String? arpError;
    try {
      arp = await BackendAPI.instance.getArpScannerStatus();
    } catch (e) {
      arpError = dioErrorToUserMessage(e);
    }

    MdnsScannerStatus? mdns;
    String? mdnsError;
    try {
      mdns = await BackendAPI.instance.getMdnsScannerStatus();
    } catch (e) {
      mdnsError = dioErrorToUserMessage(e);
    }

    if (!mounted) return;
    setState(() {
      _arpStatus = arp;
      _arpError = arpError;
      _mdnsStatus = mdns;
      _mdnsError = mdnsError;
      _statusReceivedAt = DateTime.now();
      _isLoading = false;
    });
  }

  double get _elapsed => _statusReceivedAt != null
      ? DateTime.now().difference(_statusReceivedAt!).inSeconds.toDouble()
      : 0.0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
              Text('Status', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _scannerRow(context, arpColor, 'ARP', arpText, _arpError),
              const SizedBox(height: 8),
              _scannerRow(context, mdnsColor, 'mDNS', mdnsText, _mdnsError),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scannerRow(
    BuildContext context,
    Color color,
    String name,
    String statusText,
    String? errorMessage,
  ) {
    Widget dot = Icon(Icons.circle, color: color, size: 12);
    if (errorMessage != null) {
      dot = Tooltip(message: errorMessage, child: dot);
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
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
    if (_arpError != null || _arpStatus == null) {
      return (Colors.red, 'Error');
    }
    if (_arpStatus!.isRunning) {
      final secs = (_arpStatus!.runningForSeconds ?? 0) + _elapsed;
      return (Colors.green, 'Running for ${formatSeconds(secs)}');
    }
    if (_arpStatus!.nextRunInSeconds != null) {
      final remaining = (_arpStatus!.nextRunInSeconds! - _elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (Colors.amber, 'Next run in ${formatSeconds(remaining)}');
    }
    return (Colors.grey, 'Not yet started');
  }

  (Color, String) _resolveMdns() {
    if (_mdnsError != null || _mdnsStatus == null) {
      return (Colors.red, 'Error');
    }
    if (_mdnsStatus!.isListening) {
      if (_mdnsStatus!.lastDeviceSeenSecondsAgo != null) {
        final secs = _mdnsStatus!.lastDeviceSeenSecondsAgo! + _elapsed;
        return (Colors.green, 'Last device seen ${formatSeconds(secs)} ago');
      }
      return (Colors.green, 'No devices seen yet');
    }
    return (Colors.grey, 'Not yet started');
  }
}
