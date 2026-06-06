import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mixin for [State]s that display continuously-updating elapsed-time text
/// (e.g. "Running for 3m 12s"). It runs a once-per-second timer that calls
/// [setState] so those labels stay current, and cancels it automatically on
/// dispose.
///
/// Call [startRebuildTicker] from `initState` (or when becoming visible) and
/// [stopRebuildTicker] when the widget is paused/hidden. Both are idempotent.
mixin PeriodicRebuild<T extends StatefulWidget> on State<T> {
  Timer? _rebuildTicker;

  /// Starts the per-second rebuild ticker if it isn't already running.
  void startRebuildTicker() {
    _rebuildTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Stops the per-second rebuild ticker.
  void stopRebuildTicker() {
    _rebuildTicker?.cancel();
    _rebuildTicker = null;
  }

  @override
  void dispose() {
    stopRebuildTicker();
    super.dispose();
  }
}
