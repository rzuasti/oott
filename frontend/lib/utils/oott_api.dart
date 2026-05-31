import 'dart:io';

import 'package:dio/dio.dart';
import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/foundation.dart';
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
  static const _pageSize = 5;

  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    reconfigureFromPrefs();
  }

  void reconfigureFromPrefs() {
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(_buildLogInterceptor());
    }
  }

  // Returns null if the test was successful, and a String with a message about the issue if not
  static Future<String?> test(String baseUrl, String apiKey) async {
    Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $apiKey',
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(_buildLogInterceptor());
    }

    try {
      Response response = await dio.get('/test');
      return response.toString().contains('OOTT_API_OK')
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

  Future<List<Device>> listDevices({
    bool? isRegistered,
    String? owner,
    DeviceType? deviceType,
    String? sortBy,
    bool? sortAscending,
    int? offset,
    int? limit,
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
    if (offset != null) {
      params['page_offset'] = offset;
      params['page_limit'] = limit ?? _pageSize;
    }

    final response = await _dio.get(
      '/devices',
      queryParameters: params,
      cancelToken: cancelToken,
    );

    return (response.data as List)
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList();
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

  Future<DeviceSummary> getDeviceSummary() async {
    final response = await _dio.get('/devices/summary');
    return DeviceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ArpScannerStatus> getArpScannerStatus() async {
    final response = await _dio.get('/arp_scanner/status');
    return ArpScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MdnsScannerStatus> getMdnsScannerStatus() async {
    final response = await _dio.get('/mdns_scanner/status');
    return MdnsScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Notification>> listNotifications(
    bool? isNew,
    int offset, {
    int? limit,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      '/notifications',
      queryParameters: {
        'is_new': isNew ?? '',
        'page_offset': offset,
        'page_limit': limit ?? _pageSize,
      },
      cancelToken: cancelToken,
    );

    final list = response.data as List<dynamic>;
    return List<Notification>.from(
      list.map((item) => Notification.fromJson(item)),
    );
  }
}
