import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'oott_api.dart';

class BackendReachability extends ChangeNotifier {
  BackendReachability._internal() {
    _subscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
    Connectivity().checkConnectivity().then(_handleConnectivityChange);
  }

  static final BackendReachability instance = BackendReachability._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<void> Function()? _prober;

  bool _deviceHasNetwork = true;
  bool _isBackendReachable = true;
  DateTime? _lastSuccessAt;
  DateTime? _lastFailureAt;
  String? _lastErrorMessage;
  bool _probing = false;

  bool get deviceHasNetwork => _deviceHasNetwork;
  bool get isBackendReachable => _isBackendReachable;
  bool get isOnline => _deviceHasNetwork && _isBackendReachable;
  bool get isProbing => _probing;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  DateTime? get lastFailureAt => _lastFailureAt;
  String? get lastErrorMessage => _lastErrorMessage;

  void setProber(Future<void> Function() prober) {
    _prober = prober;
  }

  void recordSuccess() {
    _lastSuccessAt = DateTime.now();
    _lastErrorMessage = null;
    final wasReachable = _isBackendReachable;
    _isBackendReachable = true;
    if (!wasReachable) notifyListeners();
  }

  void recordFailure(DioException error) {
    if (!_isConnectionLevel(error)) return;
    _lastFailureAt = DateTime.now();
    _lastErrorMessage = dioErrorToUserMessage(error);
    final wasReachable = _isBackendReachable;
    _isBackendReachable = false;
    if (wasReachable) notifyListeners();
  }

  Future<void> probe() async {
    final prober = _prober;
    if (prober == null || _probing) return;
    _probing = true;
    notifyListeners();
    try {
      await prober();
    } catch (_) {
      // Interceptor records the outcome; nothing else to do here.
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork == _deviceHasNetwork) return;
    _deviceHasNetwork = hasNetwork;
    notifyListeners();
    if (hasNetwork) {
      unawaited(probe());
    }
  }

  bool _isConnectionLevel(DioException error) {
    if (error.type == DioExceptionType.cancel) return false;
    // Anything without a response from the server is a connection-level
    // failure (timeouts, connection refused, DNS, TLS, web fetch errors
    // surfaced as DioExceptionType.unknown, etc.).
    return error.response == null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
