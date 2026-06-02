library;

import 'package:dio/dio.dart';
import 'package:encrypter/encrypter/xor.dart';

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

  /// Splits a "fetch one extra item" page into its items and a [hasNextPage]
  /// flag. Callers request `perPage + 1` items so a full extra item signals
  /// that another page exists.
  ({List<T> items, bool hasNextPage}) _paginate<T>(
    List<dynamic> data,
    T Function(dynamic) fromItem,
    int perPage,
  ) {
    final results = data.map(fromItem).toList();
    final hasNextPage = results.length > perPage;
    return (
      items: hasNextPage ? results.take(perPage).toList() : results,
      hasNextPage: hasNextPage,
    );
  }
}
