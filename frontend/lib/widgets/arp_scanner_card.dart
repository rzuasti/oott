import 'package:flutter/material.dart';
import 'package:frontend/model/arp_scanner_status.dart';

class ArpScannerCard extends StatelessWidget {
  final ArpScannerStatus? status;
  final DateTime? statusReceivedAt;
  final String? error;
  final bool isLoading;

  const ArpScannerCard({
    super.key,
    this.status,
    this.statusReceivedAt,
    this.error,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
      final remaining = (status!.nextRunInSeconds! - elapsed).clamp(
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
