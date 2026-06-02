import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';

import '../backend_reachability.dart';

const _connectTimeout = Duration(seconds: 5);
const _receiveTimeout = Duration(seconds: 15);
const _sendTimeout = Duration(seconds: 15);

const _retryableStatuses = {408, 429, 500, 502, 503, 504};

/// Builds a [Dio] client configured for the OOTT backend: base options,
/// authentication header, retry/reachability interceptors and, in debug
/// builds, request logging.
Dio buildDio({
  required String baseUrl,
  required String apiKey,
  bool withRetry = true,
  bool withReachability = true,
}) {
  final headers = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
  };
  if (apiKey.isNotEmpty) {
    headers[HttpHeaders.authorizationHeader] = 'Bearer $apiKey';
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      sendTimeout: _sendTimeout,
      headers: headers,
    ),
  );

  if (withRetry) {
    dio.interceptors.add(_buildRetryInterceptor(dio));
  }
  if (withReachability) {
    dio.interceptors.add(_buildReachabilityInterceptor());
  }
  if (kDebugMode) {
    dio.interceptors.add(_buildLogInterceptor());
  }
  return dio;
}

RetryInterceptor _buildRetryInterceptor(Dio dio) => RetryInterceptor(
  dio: dio,
  retries: 2,
  retryDelays: const [Duration(seconds: 1), Duration(seconds: 3)],
  logPrint: kDebugMode ? (msg) => debugPrint(msg.toString()) : null,
  retryEvaluator: (error, attempt) {
    if (error.requestOptions.method != 'GET') return false;
    if (error.type == DioExceptionType.cancel) return false;
    if (error.error is FormatException) return false;
    if (error.type == DioExceptionType.badResponse) {
      final status = error.response?.statusCode;
      return status != null && _retryableStatuses.contains(status);
    }
    return true;
  },
);

InterceptorsWrapper _buildReachabilityInterceptor() => InterceptorsWrapper(
  onResponse: (response, handler) {
    BackendReachability.instance.recordSuccess();
    handler.next(response);
  },
  onError: (error, handler) {
    BackendReachability.instance.recordFailure(error);
    handler.next(error);
  },
);

LogInterceptor _buildLogInterceptor() => LogInterceptor(
  request: true,
  requestHeader: false,
  requestBody: false,
  responseHeader: false,
  responseBody: false,
  error: true,
  logPrint: (obj) => debugPrint(obj.toString()),
);
