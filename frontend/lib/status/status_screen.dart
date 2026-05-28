import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/model/arp_scanner_status.dart';
import 'package:frontend/utils/oott_api.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  ArpScannerStatus? _status;
  DateTime? _statusReceivedAt;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadStatus(),
    );
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          _ArpScannerCard(
            status: _status,
            statusReceivedAt: _statusReceivedAt,
            error: _error,
          ),
      ],
    );
  }
}

class _ArpScannerCard extends StatelessWidget {
  final ArpScannerStatus? status;
  final DateTime? statusReceivedAt;
  final String? error;

  const _ArpScannerCard({this.status, this.statusReceivedAt, this.error});

  @override
  Widget build(BuildContext context) {
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
    if (error != null || status == null) {
      return (
        Colors.red,
        'Error',
        'Unable to reach the server or a server-side error occurred. Check the logs for details.',
      );
    }

    final elapsed = statusReceivedAt != null
        ? DateTime.now().difference(statusReceivedAt!).inSeconds.toDouble()
        : 0.0;

    if (status!.isRunning) {
      final sub = status!.runningForSeconds != null
          ? 'Running for ${_formatSeconds(status!.runningForSeconds! + elapsed)}'
          : null;
      return (Colors.green, 'Running', sub);
    }
    if (status!.nextRunInSeconds != null) {
      final remaining = (status!.nextRunInSeconds! - elapsed).clamp(0.0, double.infinity);
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
