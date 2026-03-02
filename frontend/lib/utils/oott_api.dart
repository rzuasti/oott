import 'dart:io';

import 'package:dio/dio.dart';
import 'package:encrypter/encrypter/xor.dart';
import 'package:frontend/utils/pref_utils.dart';
import '../model/notification.dart';

class BackendAPI {
  static final BackendAPI _instance = BackendAPI._internal();

  static BackendAPI get instance => _instance;

  BackendAPI._internal() {
    // _baseUrl =
    // PrefUtil.getValue("base_url", "http://localhost:3000/api") as String;
    // _apiKey = XOR().xorDecode(PrefUtil.getValue("api_key", "") as String);

    _baseUrl = "http://localhost:3000/api";
    _apiKey = "super_secret";

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

  late String _baseUrl;
  late String _apiKey;
  late Dio _dio;

  Future<List<Notification>> listNotifications() async {
    print('About to call /notifications');

    Response response;
    response = await _dio.get('/notifications');

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
