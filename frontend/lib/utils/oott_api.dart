import 'dart:io';

import 'package:dio/dio.dart';
import 'package:encrypter/encrypter/xor.dart';
import 'package:frontend/utils/pref_utils.dart';
import '../model/notification.dart';

class BackendAPI {
  static final BackendAPI _instance = BackendAPI._internal();
  static const _pageSize = 5;

  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    _baseUrl =
        PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    print('Base URL: $_baseUrl');
    print('API KEY $_apiKey');

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
    print('About to test API with baseUrl=$baseUrl and apiKey=$apiKey');
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
    print('About to call /notifications/$id');
    await _dio.get('/notifications/$id');
  }

  Future<List<Notification>> listNotifications(bool? isNew, int offset) async {
    print('About to call /notifications');

    Response response;
    response = await _dio.get(
      '/notifications',
      queryParameters: {
        'is_new': isNew ?? '',
        'page_offset': offset,
        'page_limit': _pageSize,
      },
    );

    print('Received: ' + response.data.toString());

    List<dynamic> list = response.data;
    print('List contains ' + list.length.toString() + ' items');

    List<Notification> events = List<Notification>.from(
      list.map((item) => Notification.fromJson(item)),
    );

    print('Parsed ' + events.length.toString() + ' events');

    return events;
  }
}
