import 'dart:async';

import 'package:flutter/material.dart';

import '../model/arp_scanner_status.dart';
import '../utils/oott_api.dart';

class ArpScannerCard extends StatefulWidget {
  const ArpScannerCard({super.key});

  @override
  State<ArpScannerCard> createState() => _ArpScannerCardState();
}

class _ArpScannerCardState extends State<ArpScannerCard> {
  ArpScannerStatus? _status;
  DateTime? _statusReceivedAt;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(),
    );
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await BackendAPI.instance.getArpScannerStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusReceivedAt = DateTime.now();
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

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

    final (color, label, sublabel) = _resolveState(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARP Scanner',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, String, String?) _resolveState(BuildContext context) {
    if (_error != null || _status == null) {
      return (
        Colors.red,
        'Error',
        'Unable to reach the server or a server-side error occurred. Check the logs for details.',
      );
    }

    final elapsed = _statusReceivedAt != null
        ? DateTime.now().difference(_statusReceivedAt!).inSeconds.toDouble()
        : 0.0;

    if (_status!.isRunning) {
      final sub = _status!.runningForSeconds != null
          ? 'Running for ${_formatSeconds(_status!.runningForSeconds! + elapsed)}'
          : null;
      return (Colors.green, 'Running', sub);
    }
    if (_status!.nextRunInSeconds != null) {
      final remaining = (_status!.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (
        Colors.amber,
        'Waiting for next run',
        'Next run in ${_formatSeconds(remaining)}',
      );
    }
    return (Colors.grey, 'Not yet started', null);
  }
}

String _formatSeconds(double seconds) {
  final total = seconds.round().clamp(0, double.maxFinite.toInt());
  if (total < 60) return '${total}s';
  final m = total ~/ 60;
  final s = total % 60;
  return '${m}m ${s}s';
}
