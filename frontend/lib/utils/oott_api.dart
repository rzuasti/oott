import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:frontend/model/event.dart';

class BackendAPI {
  BackendAPI._singleton();

  static final BackendAPI instance = BackendAPI._singleton();

  static final String _baseUrl = 'http://localhost:3000/api';
  static final String _apiKey = 'super_secret';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
      },
    ),
  );

  Future<List<Event>> listNotifications() async {
    print('About to call /notifications');

    Response response;
    response = await _dio.get('/notifications');

    print('Received: ' + response.data.toString());

    List<dynamic> list = response.data;
    print('List contains ' + list.length.toString() + ' items');

    List<Event> events = List<Event>.from(
      list.map((item) => Event.fromJson(item)),
    );

    print('Parsed ' + events.length.toString() + ' events');

    return events;
  }
}
