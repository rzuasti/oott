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

class BackendAPI {
  static final BackendAPI _instance = BackendAPI._internal();
  static const _pageSize = 5;

  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    debugPrint('Base URL: $_baseUrl');
    debugPrint('API KEY: $_apiKey');

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        },
      ),
    );
  }

  // Returns null if the test was successful, and a String with a message about the issue if not
  static Future<String?> test(String baseUrl, String apiKey) async {
    debugPrint('About to test API with baseUrl=$baseUrl and apiKey=$apiKey');
    Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
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
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response!.statusCode == 401) {
          return "Authorization failed, check your API Key.";
        } else {
          return "Error querying the given URL (${e.response!.statusCode} - ${e.message ?? 'N/A'})";
        }
      } else {
        // Response was null, something happened while sending the message
        return "Error sending message to provided URL (${e.message ?? 'no message'})";
      }
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

    final response = await _dio.get('/devices', queryParameters: params);

    debugPrint('Received: ${response.data}');

    return (response.data as List)
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerDevice(
    String macAddress,
    String owner,
    String deviceType,
  ) async {
    debugPrint('About to call PUT /devices');
    await _dio.put(
      '/devices',
      data: {
        'mac_address': macAddress,
        'owner': owner,
        'device_type': deviceType,
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
