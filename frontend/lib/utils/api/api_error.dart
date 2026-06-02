import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String dioErrorToUserMessage(Object error) {
  if (error is TypeError || error is FormatException) {
    debugPrint('Backend response shape error: $error');
    return 'Unexpected response shape from backend.';
  }
  if (error is! DioException) {
    debugPrint('Non-Dio error from backend call: $error');
    return 'Unexpected error.';
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Backend did not respond in time.';
    case DioExceptionType.connectionError:
      return 'Cannot reach backend. Check the base URL and your network.';
    case DioExceptionType.badCertificate:
      return 'Backend TLS certificate could not be verified.';
    case DioExceptionType.cancel:
      return 'Request canceled.';
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return 'Authentication failed. Check your API key in Settings.';
      }
      if (status == 404) {
        return 'Not found.';
      }
      if (status != null && status >= 500 && status < 600) {
        return 'Backend error (status $status). Please try again.';
      }
      return 'Unexpected response from backend (status ${status ?? 'unknown'}).';
    case DioExceptionType.unknown:
      debugPrint('Unknown Dio error: ${error.message}');
      return 'Unexpected error contacting backend.';
  }
}
