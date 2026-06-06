part of '../oott_api.dart';

/// Notification endpoints: listing and read/new state transitions.
extension NotificationApi on BackendAPI {
  Future<void> markNotificationAsRead(int id) async {
    await _dio.get('/notifications/$id');
  }

  Future<void> markNotificationAsNew(int id) async {
    await _dio.post('/notifications/$id/mark_as_new');
  }

  Future<void> markAllNotificationsAsRead() async {
    await _dio.post('/notifications/mark_all_as_old');
  }

  Future<({List<Notification> items, int totalCount})> listNotifications(
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
        'page_limit': perPage,
      },
      cancelToken: cancelToken,
    );

    return _paginate(
      response.data as Map<String, dynamic>,
      (item) => Notification.fromJson(item),
    );
  }
}
