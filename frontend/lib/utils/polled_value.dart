import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'oott_api.dart';

enum PolledFreshness { initialLoading, fresh, stale, error }

class PolledValue<T> extends ChangeNotifier {
  PolledValue({
    required Future<T> Function({CancelToken? cancelToken}) fetch,
    required Duration pollInterval,
    required Duration staleErrorAfter,
  }) : _fetch = fetch,
       _staleErrorAfter = staleErrorAfter {
    _load();
    _pollTimer = Timer.periodic(pollInterval, (_) => _load());
  }

  final Future<T> Function({CancelToken? cancelToken}) _fetch;
  final Duration _staleErrorAfter;
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

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
