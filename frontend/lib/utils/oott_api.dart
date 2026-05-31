import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/utils/backend_reachability.dart';
import 'package:frontend/utils/pref_utils.dart';
import '../model/arp_scanner_status.dart';
import '../model/mdns_scanner_status.dart';
import '../model/device.dart';
import '../model/device_event.dart';
import '../model/device_summary.dart';
import '../model/device_type.dart';
import '../model/notification.dart';

const _connectTimeout = Duration(seconds: 5);
const _receiveTimeout = Duration(seconds: 15);
const _sendTimeout = Duration(seconds: 15);

const _retryableStatuses = {408, 429, 500, 502, 503, 504};

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

String dioErrorToUserMessage(Object error) {
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

class BackendAPI {
  static final BackendAPI _instance = BackendAPI._internal();
  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    reconfigureFromPrefs();
  }

  void reconfigureFromPrefs() {
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (_apiKey.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_apiKey';
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: headers,
      ),
    );
    _dio.interceptors.add(_buildRetryInterceptor(_dio));
    _dio.interceptors.add(_buildReachabilityInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(_buildLogInterceptor());
    }
    BackendReachability.instance.setProber(() => _dio.get('/test'));
  }

  // Returns null if the test was successful, and a String with a message about the issue if not
  static Future<String?> test(String baseUrl, String apiKey) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $apiKey';
    }

    Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: headers,
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(_buildLogInterceptor());
    }

    try {
      Response response = await dio.get('/test');
      return response.data == 'OOTT_API_OK'
          ? null
          : "URL successfully called but didn't return the expected value. Check your URL and make sure it points to your OOTT backend base URL.";
    } catch (e) {
      return dioErrorToUserMessage(e);
    }
  }

  late String _baseUrl;
  late String _apiKey;
  late Dio _dio;

  Future<void> markNotificationAsRead(int id) async {
    await _dio.get('/notifications/$id');
  }

  Future<void> markNotificationAsNew(int id) async {
    await _dio.post('/notifications/$id/mark_as_new');
  }

  Future<void> markAllNotificationsAsRead() async {
    await _dio.post('/notifications/mark_all_as_old');
  }

  Future<Device> getDevice(String macAddress) async {
    final response = await _dio.get('/devices/$macAddress');
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({List<Device> items, bool hasNextPage})> listDevices({
    bool? isRegistered,
    String? owner,
    DeviceType? deviceType,
    String? sortBy,
    bool? sortAscending,
    int page = 0,
    int perPage = 10,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{};
    if (isRegistered != null) params['is_registered'] = isRegistered;
    if (owner != null && owner.isNotEmpty) params['owner'] = owner;
    if (deviceType != null) {
      params['device_type'] = deviceType == DeviceType.unknown
          ? ''
          : deviceType.apiName;
    }
    if (sortBy != null) params['sort_by'] = sortBy;
    if (sortAscending != null) {
      params['sort_order'] = sortAscending ? 'asc' : 'desc';
    }
    params['page_offset'] = page * perPage;
    params['page_limit'] = perPage + 1;

    final response = await _dio.get(
      '/devices',
      queryParameters: params,
      cancelToken: cancelToken,
    );

    final results = (response.data as List)
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList();
    final hasNextPage = results.length > perPage;
    return (
      items: hasNextPage ? results.take(perPage).toList() : results,
      hasNextPage: hasNextPage,
    );
  }

  Future<void> registerDevice(
    String macAddress,
    String owner,
    String deviceType, {
    String? name,
  }) async {
    await _dio.put(
      '/devices',
      data: {
        'mac_address': macAddress,
        'owner': owner,
        'device_type': deviceType,
        'name': ?name,
      },
    );
  }

  Future<void> updateDevice(
    String macAddress,
    String owner,
    String deviceType,
    String vendor, {
    String? name,
  }) async {
    await _dio.put(
      '/devices/$macAddress',
      data: {
        'owner': owner,
        'device_type': deviceType,
        'vendor': vendor,
        'name': name,
      },
    );
  }

  Future<void> forgetDevice(String macAddress) async {
    await _dio.delete('/devices/$macAddress');
  }

  Future<List<DeviceEvent>> getDeviceEvents(
    String macAddress, {
    DateTime? createdFrom,
  }) async {
    final queryParams = <String, dynamic>{};
    if (createdFrom != null) {
      queryParams['created_from'] = createdFrom.toUtc().toIso8601String();
    }
    final response = await _dio.get(
      '/devices/$macAddress/events',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return (response.data as List)
        .map((item) => DeviceEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceSummary> getDeviceSummary({CancelToken? cancelToken}) async {
    final response = await _dio.get(
      '/devices/summary',
      cancelToken: cancelToken,
    );
    return DeviceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ArpScannerStatus> getArpScannerStatus({
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      '/arp_scanner/status',
      cancelToken: cancelToken,
    );
    return ArpScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MdnsScannerStatus> getMdnsScannerStatus({
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      '/mdns_scanner/status',
      cancelToken: cancelToken,
    );
    return MdnsScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({List<Notification> items, bool hasNextPage})> listNotifications(
    bool? isNew, {
    int page = 0,
    int perPage = 5,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      '/notifications',
      queryParameters: {
        'is_new': isNew ?? '',
        'page_offset': page * perPage,
        'page_limit': perPage + 1,
      },
      cancelToken: cancelToken,
    );

    final results = (response.data as List<dynamic>)
        .map((item) => Notification.fromJson(item))
        .toList();
    final hasNextPage = results.length > perPage;
    return (
      items: hasNextPage ? results.take(perPage).toList() : results,
      hasNextPage: hasNextPage,
    );
  }
}
