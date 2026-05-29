import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/mdns_scanner_status.dart';
import '../utils/duration_formatter.dart';
import '../utils/oott_api.dart';

class MdnsScannerCard extends StatefulWidget {
  const MdnsScannerCard({super.key});

  @override
  State<MdnsScannerCard> createState() => _MdnsScannerCardState();
}

class _MdnsScannerCardState extends State<MdnsScannerCard> {
  MdnsScannerStatus? _status;
  DateTime? _statusReceivedAt;
  bool _isLoading = true;
  String? _error;
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
    try {
      final status = await BackendAPI.instance.getMdnsScannerStatus();
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

    final (color, label, sublabels) = _resolveState(context);

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
                    Text(
                      'mDNS Scanner',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    for (final sublabel in sublabels) ...[
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
      ),
    );
  }

  (Color, String, List<String>) _resolveState(BuildContext context) {
    if (_error != null || _status == null) {
      return (
        Colors.red,
        'Error',
        [
          'Unable to reach the server or a server-side error occurred. Check the logs for details.',
        ],
      );
    }

    final elapsed = _statusReceivedAt != null
        ? DateTime.now().difference(_statusReceivedAt!).inSeconds.toDouble()
        : 0.0;

    if (_status!.isListening) {
      final sublabels = <String>[];
      if (_status!.listeningForSeconds != null) {
        sublabels.add(
          'Listening for ${formatSeconds(_status!.listeningForSeconds! + elapsed)} · ${_status!.devicesSeen} devices seen',
        );
      } else {
        sublabels.add('${_status!.devicesSeen} devices seen');
      }
      if (_status!.lastDeviceSeenSecondsAgo != null) {
        sublabels.add(
          'Last device ${formatSeconds(_status!.lastDeviceSeenSecondsAgo! + elapsed)} ago',
        );
      }
      return (Colors.green, 'Listening', sublabels);
    }

    return (Colors.grey, 'Not yet started', <String>[]);
  }
}
