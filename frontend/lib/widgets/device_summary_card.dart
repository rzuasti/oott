import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device_summary.dart';
import '../utils/backend_reachability.dart';
import '../utils/oott_api.dart';
import '../utils/polled_value.dart';
import 'polled_stale_indicator.dart';
import '../theme/dimens.dart';
import '../routes.dart';

class DeviceSummaryCard extends StatefulWidget {
  const DeviceSummaryCard({super.key});

  @override
  State<DeviceSummaryCard> createState() => _DeviceSummaryCardState();
}

class _DeviceSummaryCardState extends State<DeviceSummaryCard> {
  late final PolledValue<DeviceSummary> _polled;

  @override
  void initState() {
    super.initState();
    _polled = PolledValue<DeviceSummary>(
      fetch: ({cancelToken}) =>
          BackendAPI.instance.getDeviceSummary(cancelToken: cancelToken),
      pollInterval: const Duration(minutes: 1),
      staleErrorAfter: const Duration(minutes: 3),
    );
  }

  @override
  void dispose() {
    _polled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.devices),
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _polled,
              BackendReachability.instance,
            ]),
            builder: (context, _) {
              final freshness = effectiveFreshness(_polled);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (freshness == PolledFreshness.stale) ...[
                        const SizedBox(width: 6),
                        PolledStaleIndicator(polled: _polled),
                      ],
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  ..._buildBody(context, freshness),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, PolledFreshness freshness) {
    switch (freshness) {
      case PolledFreshness.initialLoading:
        return const [Center(child: CircularProgressIndicator())];
      case PolledFreshness.error:
        return [
          Text(
            _polled.lastErrorMessage ?? 'Error loading device summary',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ];
      case PolledFreshness.fresh:
      case PolledFreshness.stale:
        final summary = _polled.value!;
        return [
          _SummaryRow(
            label: 'Registered in the system',
            value: '${summary.totalRegistered}',
          ),
          const Divider(height: 20),
          Text(
            'Seen in the last 24 hours',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Registered',
            value: '${summary.seenLastDayRegistered}',
          ),
          _SummaryRow(
            label: 'Unregistered',
            value: '${summary.seenLastDayUnregistered}',
          ),
          const Divider(height: 20),
          Text(
            'Seen in the last 7 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Registered',
            value: '${summary.seenLastWeekRegistered}',
          ),
          _SummaryRow(
            label: 'Unregistered',
            value: '${summary.seenLastWeekUnregistered}',
          ),
        ];
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
