import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/arp_scanner_status.dart';
import '../utils/backend_reachability.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';

class ArpScannerCard extends StatefulWidget {
  const ArpScannerCard({super.key});

  @override
  State<ArpScannerCard> createState() => _ArpScannerCardState();
}

class _ArpScannerCardState extends State<ArpScannerCard> {
  late final PolledValue<ArpScannerStatus> _polled;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _polled = PolledValue<ArpScannerStatus>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getArpScannerStatus(cancelToken: cancelToken),
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
    _polled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_polled, BackendReachability.instance]),
      builder: (context, _) {
        final freshness = effectiveFreshness(_polled);
        if (freshness == PolledFreshness.initialLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final (color, label, sublabel) = _resolveState(freshness);
        final isStale = freshness == PolledFreshness.stale;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/status'),
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
                        Row(
                          children: [
                            Text(
                              'ARP Scanner',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (isStale) ...[
                              const SizedBox(width: 6),
                              PolledStaleIndicator(polled: _polled),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (sublabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
          ),
        );
      },
    );
  }

  (Color, String, String?) _resolveState(PolledFreshness freshness) {
    if (freshness == PolledFreshness.error) {
      return (
        Colors.red,
        'Error',
        _polled.lastErrorMessage ??
            'Unable to reach the server. Check the logs for details.',
      );
    }

    final status = _polled.value!;
    final lastSuccessAt = _polled.lastSuccessAt!;
    final elapsed = DateTime.now()
        .difference(lastSuccessAt)
        .inSeconds
        .toDouble();

    if (status.isRunning) {
      final sub = status.runningForSeconds != null
          ? 'Running for ${formatSeconds(status.runningForSeconds! + elapsed)}'
          : null;
      return (Colors.green, 'Running', sub);
    }
    if (status.nextRunInSeconds != null) {
      final remaining = (status.nextRunInSeconds! - elapsed).clamp(
        0.0,
        double.infinity,
      );
      return (
        Colors.amber,
        'Waiting for next run',
        'Next run in ${formatSeconds(remaining)}',
      );
    }
    return (Colors.grey, 'Not yet started', null);
  }
}
