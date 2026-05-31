import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/mdns_scanner_status.dart';
import '../utils/backend_reachability.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';

class MdnsScannerCard extends StatefulWidget {
  const MdnsScannerCard({super.key});

  @override
  State<MdnsScannerCard> createState() => _MdnsScannerCardState();
}

class _MdnsScannerCardState extends State<MdnsScannerCard> {
  late final PolledValue<MdnsScannerStatus> _polled;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _polled = PolledValue<MdnsScannerStatus>(
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

        final (color, label, sublabels) = _resolveState(freshness);
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
                              'mDNS Scanner',
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
                        for (final sublabel in sublabels) ...[
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

  (Color, String, List<String>) _resolveState(PolledFreshness freshness) {
    if (freshness == PolledFreshness.error) {
      return (
        Colors.red,
        'Error',
        [
          _polled.lastErrorMessage ??
              'Unable to reach the server. Check the logs for details.',
        ],
      );
    }

    final status = _polled.value!;
    final lastSuccessAt = _polled.lastSuccessAt!;
    final elapsed = DateTime.now()
        .difference(lastSuccessAt)
        .inSeconds
        .toDouble();

    if (status.isListening) {
      final sublabels = <String>[];
      if (status.listeningForSeconds != null) {
        sublabels.add(
          'Listening for ${formatSeconds(status.listeningForSeconds! + elapsed)} · ${status.devicesSeen} devices seen',
        );
      } else {
        sublabels.add('${status.devicesSeen} devices seen');
      }
      if (status.lastDeviceSeenSecondsAgo != null) {
        sublabels.add(
          'Last device ${formatSeconds(status.lastDeviceSeenSecondsAgo! + elapsed)} ago',
        );
      }
      return (Colors.green, 'Listening', sublabels);
    }

    return (Colors.grey, 'Not yet started', <String>[]);
  }
}
