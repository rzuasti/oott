part of '../oott_api.dart';

/// Device endpoints: lookup, listing, registration, updates and event history.
extension DeviceApi on BackendAPI {
  Future<Device> getDevice(String macAddress) =>
      _getModel('/devices/$macAddress', Device.fromJson);

  Future<({List<Device> items, int totalCount})> listDevices({
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
    params['page_limit'] = perPage;

    final response = await _dio.get(
      '/devices',
      queryParameters: params,
      cancelToken: cancelToken,
    );

    return _paginate(
      response.data as Map<String, dynamic>,
      (item) => Device.fromJson(item as Map<String, dynamic>),
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

  Future<DeviceSummary> getDeviceSummary({CancelToken? cancelToken}) =>
      _getModel(
        '/devices/summary',
        DeviceSummary.fromJson,
        cancelToken: cancelToken,
      );
}
