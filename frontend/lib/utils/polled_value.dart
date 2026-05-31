import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'backend_reachability.dart';
import 'oott_api.dart';

enum PolledFreshness { initialLoading, fresh, stale, error }

enum PolledPauseReason { manual, unreachable }

/// Returns the freshness of [polled] downgraded to [PolledFreshness.stale]
/// when the backend is known to be unreachable and a previous value exists.
/// This avoids showing per-card error chrome while the global offline banner
/// is already communicating the connectivity issue.
PolledFreshness effectiveFreshness(PolledValue polled) {
  final base = polled.freshness;
  if (base == PolledFreshness.error &&
      polled.value != null &&
      !BackendReachability.instance.isOnline) {
    return PolledFreshness.stale;
  }
  return base;
}

class PolledValue<T> extends ChangeNotifier {
  PolledValue({
    required Future<T> Function({CancelToken? cancelToken}) fetch,
    required Duration pollInterval,
    required Duration staleErrorAfter,
  }) : _fetch = fetch,
       _pollInterval = pollInterval,
       _staleErrorAfter = staleErrorAfter {
    _reachability = BackendReachability.instance;
    _reachability.addListener(_onReachabilityChanged);
    if (!_reachability.isOnline) {
      _pauseReasons.add(PolledPauseReason.unreachable);
    }
    if (_pauseReasons.isEmpty) {
      _load();
      _startPolling();
    }
  }

  final Future<T> Function({CancelToken? cancelToken}) _fetch;
  final Duration _pollInterval;
  final Duration _staleErrorAfter;
  final Set<PolledPauseReason> _pauseReasons = {};
  late final BackendReachability _reachability;

  Timer? _pollTimer;
  CancelToken? _cancelToken;
  bool _disposed = false;

  T? _value;
  DateTime? _lastSuccessAt;
  String? _lastErrorMessage;
  bool _everCompleted = false;

  T? get value => _value;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  String? get lastErrorMessage => _lastErrorMessage;

  PolledFreshness get freshness {
    if (!_everCompleted && _value == null) {
      return PolledFreshness.initialLoading;
    }
    final last = _lastSuccessAt;
    if (_value == null || last == null) return PolledFreshness.error;
    if (_lastErrorMessage == null) return PolledFreshness.fresh;
    return DateTime.now().difference(last) >= _staleErrorAfter
        ? PolledFreshness.error
        : PolledFreshness.stale;
  }

  Future<void> _load() async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;
    try {
      final result = await _fetch(cancelToken: token);
      if (_disposed || token != _cancelToken) return;
      _value = result;
      _lastSuccessAt = DateTime.now();
      _lastErrorMessage = null;
      _everCompleted = true;
      notifyListeners();
    } catch (e) {
      if (_disposed || token != _cancelToken) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _lastErrorMessage = dioErrorToUserMessage(e);
      _everCompleted = true;
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _load());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelToken?.cancel();
  }

  void pauseFor(PolledPauseReason reason) {
    final added = _pauseReasons.add(reason);
    if (added && _pauseReasons.length == 1) {
      _stopPolling();
    }
  }

  void resumeFor(PolledPauseReason reason) {
    if (_disposed) return;
    final removed = _pauseReasons.remove(reason);
    if (removed && _pauseReasons.isEmpty) {
      _load();
      _startPolling();
    }
  }

  void pause() => pauseFor(PolledPauseReason.manual);

  void resume() => resumeFor(PolledPauseReason.manual);

  void _onReachabilityChanged() {
    if (_reachability.isOnline) {
      resumeFor(PolledPauseReason.unreachable);
    } else {
      pauseFor(PolledPauseReason.unreachable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reachability.removeListener(_onReachabilityChanged);
    _stopPolling();
    super.dispose();
  }
}
