import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/device_summary.dart';
import '../utils/oott_api.dart';

class DeviceSummaryCard extends StatefulWidget {
  const DeviceSummaryCard({super.key});

  @override
  State<DeviceSummaryCard> createState() => _DeviceSummaryCardState();
}

class _DeviceSummaryCardState extends State<DeviceSummaryCard> {
  DeviceSummary? _summary;
  bool _isLoading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final summary = await BackendAPI.instance.getDeviceSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/devices'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Devices', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(
                  'Error loading device summary',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (_summary != null) ...[
                _SummaryRow(
                  label: 'Registered in the system',
                  value: '${_summary!.totalRegistered}',
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
                  value: '${_summary!.seenLastDayRegistered}',
                ),
                _SummaryRow(
                  label: 'Unregistered',
                  value: '${_summary!.seenLastDayUnregistered}',
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
                  value: '${_summary!.seenLastWeekRegistered}',
                ),
                _SummaryRow(
                  label: 'Unregistered',
                  value: '${_summary!.seenLastWeekUnregistered}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
