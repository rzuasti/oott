library;

import 'package:dio/dio.dart';
import 'package:encrypter/encrypter/xor.dart';
import 'package:flutter/foundation.dart';

import 'api/api_error.dart';
import 'api/dio_config.dart';
import 'backend_reachability.dart';
import 'pref_utils.dart';
import '../model/arp_scanner_status.dart';
import '../model/dhcp_scanner_status.dart';
import '../model/mdns_scanner_status.dart';
import '../model/ssdp_scanner_status.dart';
import '../model/snmp_scanner_status.dart';
import '../model/device.dart';
import '../model/device_event.dart';
import '../model/device_summary.dart';
import '../model/device_type.dart';
import '../model/notification.dart';

export 'api/api_error.dart';

part 'api/oott_api_devices.dart';
part 'api/oott_api_scanners.dart';
part 'api/oott_api_notifications.dart';

class BackendAPI {
  static final BackendAPI _instance = BackendAPI._internal();
  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    reconfigureFromPrefs();
  }

  late String _baseUrl;
  late String _apiKey;
  late Dio _dio;

  void reconfigureFromPrefs() {
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    _dio = buildDio(baseUrl: _baseUrl, apiKey: _apiKey);
    BackendReachability.instance.setProber(() => _dio.get('/test'));
  }

  /// Test-only access to the underlying [Dio] so tests can swap in a client
  /// with a mock adapter installed. Mirrors [reconfigureFromPrefs]'s prober
  /// wiring so reachability stays consistent after a swap.
  @visibleForTesting
  Dio get dioForTesting => _dio;

  @visibleForTesting
  set dioForTesting(Dio dio) {
    _dio = dio;
    BackendReachability.instance.setProber(() => _dio.get('/test'));
  }

  // Returns null if the test was successful, and a String with a message about the issue if not
  static Future<String?> test(String baseUrl, String apiKey) async {
    final dio = buildDio(
      baseUrl: baseUrl,
      apiKey: apiKey,
      withRetry: false,
      withReachability: false,
    );

    try {
      final response = await dio.get('/test');
      return response.data == 'OOTT_API_OK'
          ? null
          : "URL successfully called but didn't return the expected value. Check your URL and make sure it points to your OOTT backend base URL.";
    } catch (e) {
      return dioErrorToUserMessage(e);
    }
  }

  /// Fetches [path] and decodes the JSON object response with [fromJson].
  Future<T> _getModel<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(path, cancelToken: cancelToken);
    return fromJson(response.data as Map<String, dynamic>);
  }

  /// Decodes a paged list response of the shape `{items: [...], total_count: N}`
  /// into the page's items and the total number of rows matching the request's
  /// filters. The total lets callers report how many pages exist and offer a
  /// "go to last page" control.
  ({List<T> items, int totalCount}) _paginate<T>(
    Map<String, dynamic> data,
    T Function(dynamic) fromItem,
  ) {
    final items = (data['items'] as List<dynamic>).map(fromItem).toList();
    return (items: items, totalCount: data['total_count'] as int);
  }
}
