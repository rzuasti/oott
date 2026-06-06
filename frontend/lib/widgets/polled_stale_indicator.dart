import 'package:flutter/material.dart';

import '../utils/backend_reachability.dart';
import '../utils/duration_formatter.dart';
import '../utils/periodic_rebuild.dart';
import '../utils/polled_value.dart';

class PolledStaleIndicator extends StatefulWidget {
  const PolledStaleIndicator({super.key, required this.polled});

  final PolledValue polled;

  @override
  State<PolledStaleIndicator> createState() => _PolledStaleIndicatorState();
}

class _PolledStaleIndicatorState extends State<PolledStaleIndicator>
    with PeriodicRebuild<PolledStaleIndicator> {
  @override
  void initState() {
    super.initState();
    startRebuildTicker();
  }

  @override
  Widget build(BuildContext context) {
    final lastSuccessAt = widget.polled.lastSuccessAt;
    final ago = lastSuccessAt != null
        ? formatSeconds(
            DateTime.now().difference(lastSuccessAt).inSeconds.toDouble(),
          )
        : 'a while';
    final isOffline = !BackendReachability.instance.isOnline;
    final String message;
    if (isOffline) {
      message = 'Offline — last updated $ago ago';
    } else if (widget.polled.lastErrorMessage != null) {
      message = 'Last updated $ago ago — ${widget.polled.lastErrorMessage}';
    } else {
      message = 'Last updated $ago ago';
    }
    return Tooltip(
      message: message,
      child: Icon(
        Icons.warning_amber_rounded,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
