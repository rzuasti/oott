import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/api/api_error.dart';

void main() {
  final options = RequestOptions(path: '/x');

  DioException dio(DioExceptionType type, {int? status}) => DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );

  test('maps shape errors', () {
    expect(
      dioErrorToUserMessage(TypeError()),
      'Unexpected response shape from backend.',
    );
    expect(
      dioErrorToUserMessage(const FormatException('bad')),
      'Unexpected response shape from backend.',
    );
  });

  test('maps non-Dio errors to a generic message', () {
    expect(dioErrorToUserMessage(Exception('boom')), 'Unexpected error.');
  });

  test('maps timeouts', () {
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.connectionTimeout)),
      'Backend did not respond in time.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.receiveTimeout)),
      'Backend did not respond in time.',
    );
  });

  test('maps connection and certificate errors', () {
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.connectionError)),
      'Cannot reach backend. Check the base URL and your network.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badCertificate)),
      'Backend TLS certificate could not be verified.',
    );
  });

  test('maps bad responses by status code', () {
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badResponse, status: 401)),
      'Authentication failed. Check your API key in Settings.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badResponse, status: 403)),
      'Authentication failed. Check your API key in Settings.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badResponse, status: 404)),
      'Not found.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badResponse, status: 503)),
      'Backend error (status 503). Please try again.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.badResponse, status: 418)),
      'Unexpected response from backend (status 418).',
    );
  });

  test('maps cancellation and unknown errors', () {
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.cancel)),
      'Request canceled.',
    );
    expect(
      dioErrorToUserMessage(dio(DioExceptionType.unknown)),
      'Unexpected error contacting backend.',
    );
  });
}
