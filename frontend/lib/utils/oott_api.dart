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
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    debugPrint('Base URL: $_baseUrl');
    debugPrint('API KEY: ${_apiKey.isEmpty ? "<empty>" : "<set>"}');

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
  }

  // Returns null if the test was successful, and a String with a message about the issue if not
  static Future<String?> test(String baseUrl, String apiKey) async {
    debugPrint('About to test API with baseUrl=$baseUrl');
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
    debugPrint('About to call /notifications/$id');
    await _dio.get('/notifications/$id');
  }

  Future<void> markNotificationAsNew(int id) async {
    debugPrint('About to call /notifications/$id/mark_as_new');
    await _dio.post('/notifications/$id/mark_as_new');
  }

  Future<void> markAllNotificationsAsRead() async {
    debugPrint('About to call /notifications/mark_all_as_old');
    await _dio.post('/notifications/mark_all_as_old');
  }

  Future<Device> getDevice(String macAddress) async {
    debugPrint('About to call GET /devices/$macAddress');
    final response = await _dio.get('/devices/$macAddress');
    debugPrint('Received: ${response.data}');
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
  }) async {
    debugPrint('About to call /devices');

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

    final response = await _dio.get('/devices', queryParameters: params);

    debugPrint('Received: ${response.data}');

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
    debugPrint('About to call PUT /devices');
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
    debugPrint('About to call PUT /devices/$macAddress');
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
    debugPrint('About to call DELETE /devices/$macAddress');
    await _dio.delete('/devices/$macAddress');
  }

  Future<List<DeviceEvent>> getDeviceEvents(
    String macAddress, {
    DateTime? createdFrom,
  }) async {
    debugPrint('About to call GET /devices/$macAddress/events');
    final queryParams = <String, dynamic>{};
    if (createdFrom != null) {
      queryParams['created_from'] = createdFrom.toUtc().toIso8601String();
    }
    final response = await _dio.get(
      '/devices/$macAddress/events',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    debugPrint('Received: ${response.data}');
    return (response.data as List)
        .map((item) => DeviceEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceSummary> getDeviceSummary() async {
    debugPrint('About to call GET /devices/summary');
    final response = await _dio.get('/devices/summary');
    debugPrint('Received: ${response.data}');
    return DeviceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ArpScannerStatus> getArpScannerStatus() async {
    debugPrint('About to call GET /arp_scanner/status');
    final response = await _dio.get('/arp_scanner/status');
    debugPrint('Received: ${response.data}');
    return ArpScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MdnsScannerStatus> getMdnsScannerStatus() async {
    debugPrint('About to call GET /mdns_scanner/status');
    final response = await _dio.get('/mdns_scanner/status');
    debugPrint('Received: ${response.data}');
    return MdnsScannerStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Notification>> listNotifications(
    bool? isNew,
    int offset, {
    int? limit,
  }) async {
    debugPrint('About to call /notifications');

    Response response;
    response = await _dio.get(
      '/notifications',
      queryParameters: {
        'is_new': isNew ?? '',
        'page_offset': offset,
        'page_limit': limit ?? _pageSize,
      },
    );

    debugPrint('Received: ${response.data}');

    List<dynamic> list = response.data;
    debugPrint('List contains ${list.length} items');

    List<Notification> events = List<Notification>.from(
      list.map((item) => Notification.fromJson(item)),
    );

    debugPrint('Parsed ${events.length} events');

    return events;
  }
}
