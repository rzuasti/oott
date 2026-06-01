import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/backend_reachability.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';

typedef ScannerStatus = ({Color color, String label, List<String> sublabels});

typedef ScannerStatusResolver<T> =
    ScannerStatus Function(BuildContext context, T value, double elapsedSeconds);

/// Generic card that polls a scanner status endpoint and renders the result
/// using the provided [resolver]. The two scanner cards (ARP, mDNS) are thin
/// wrappers over this widget.
class ScannerStatusCard<T> extends StatefulWidget {
  const ScannerStatusCard({
    super.key,
    required this.title,
    required this.fetch,
    required this.resolver,
  });

  final String title;
  final Future<T> Function({CancelToken? cancelToken}) fetch;
  final ScannerStatusResolver<T> resolver;

  @override
  State<ScannerStatusCard<T>> createState() => _ScannerStatusCardState<T>();
}

class _ScannerStatusCardState<T> extends State<ScannerStatusCard<T>> {
  late final PolledValue<T> _polled;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _polled = PolledValue<T>(
      fetch: widget.fetch,
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

        final status = _resolveStatus(context, freshness);
        final isStale = freshness == PolledFreshness.stale;
        final theme = Theme.of(context);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/status'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.circle, color: status.color, size: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (isStale) ...[
                              const SizedBox(width: 6),
                              PolledStaleIndicator(polled: _polled),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(status.label, style: theme.textTheme.bodyMedium),
                        for (final sublabel in status.sublabels) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
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

  ScannerStatus _resolveStatus(BuildContext context, PolledFreshness freshness) {
    if (freshness == PolledFreshness.error) {
      return (
        color: Theme.of(context).colorScheme.error,
        label: 'Error',
        sublabels: [
          _polled.lastErrorMessage ??
              'Unable to reach the server. Check the logs for details.',
        ],
      );
    }
    final elapsed = DateTime.now()
        .difference(_polled.lastSuccessAt!)
        .inSeconds
        .toDouble();
    return widget.resolver(context, _polled.value as T, elapsed);
  }
}
