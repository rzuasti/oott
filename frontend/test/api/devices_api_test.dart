import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/device_type.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/fixtures.dart';

void main() {
  late DioAdapter adapter;

  setUp(() async {
    adapter = await setUpBackendForTest();
  });

  test('getDevice fetches and decodes a single device', () async {
    adapter.onGet(
      '/devices/aa:bb:cc:dd:ee:ff',
      (server) => server.reply(200, deviceJson(owner: 'carol')),
    );

    final device = await BackendAPI.instance.getDevice('aa:bb:cc:dd:ee:ff');

    expect(device.owner, 'carol');
  });

  test('getDeviceSummary GETs /devices/summary', () async {
    adapter.onGet(
      '/devices/summary',
      (server) => server.reply(200, deviceSummaryJson(totalRegistered: 7)),
    );

    final summary = await BackendAPI.instance.getDeviceSummary();

    expect(summary.totalRegistered, 7);
  });

  test('listDevices sends filter + pagination params and trims extra item',
      () async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, [
        deviceJson(macAddress: '00:00:00:00:00:01'),
        deviceJson(macAddress: '00:00:00:00:00:02'),
        deviceJson(macAddress: '00:00:00:00:00:03'),
      ]),
      queryParameters: {
        'is_registered': false,
        'device_type': 'laptop',
        'sort_by': 'last_seen',
        'sort_order': 'asc',
        'page_offset': 0,
        'page_limit': 3,
      },
    );

    final result = await BackendAPI.instance.listDevices(
      isRegistered: false,
      deviceType: DeviceType.laptop,
      sortBy: 'last_seen',
      sortAscending: true,
      page: 0,
      perPage: 2,
    );

    expect(result.items, hasLength(2));
    expect(result.hasNextPage, isTrue);
  });

  test('listDevices reports no next page when fewer than perPage+1 returned',
      () async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, [deviceJson()]),
    );

    final result = await BackendAPI.instance.listDevices(perPage: 2);

    expect(result.items, hasLength(1));
    expect(result.hasNextPage, isFalse);
  });

  test('listDevices maps the unknown device type to an empty filter', () async {
    adapter.onGet(
      '/devices',
      (server) => server.reply(200, <dynamic>[]),
      queryParameters: {
        'device_type': '',
        'page_offset': 0,
        'page_limit': 11,
      },
    );

    final result = await BackendAPI.instance.listDevices(
      deviceType: DeviceType.unknown,
    );

    expect(result.items, isEmpty);
  });

  test('registerDevice PUTs the device payload', () async {
    adapter.onPut(
      '/devices',
      (server) => server.reply(200, null),
      data: {
        'mac_address': 'aa:bb:cc:dd:ee:ff',
        'owner': 'dave',
        'device_type': 'phone',
        'name': 'Dave Phone',
      },
    );

    await BackendAPI.instance.registerDevice(
      'aa:bb:cc:dd:ee:ff',
      'dave',
      'phone',
      name: 'Dave Phone',
    );
  });

  test('updateDevice PUTs to the device path', () async {
    adapter.onPut(
      '/devices/aa:bb:cc:dd:ee:ff',
      (server) => server.reply(200, null),
      data: {
        'owner': 'erin',
        'device_type': 'tv',
        'vendor': 'Globex',
        'name': null,
      },
    );

    await BackendAPI.instance.updateDevice(
      'aa:bb:cc:dd:ee:ff',
      'erin',
      'tv',
      'Globex',
    );
  });

  test('forgetDevice DELETEs the device path', () async {
    adapter.onDelete(
      '/devices/aa:bb:cc:dd:ee:ff',
      (server) => server.reply(200, null),
    );

    await BackendAPI.instance.forgetDevice('aa:bb:cc:dd:ee:ff');
  });

  test('getDeviceEvents decodes a list of events', () async {
    adapter.onGet(
      '/devices/aa:bb:cc:dd:ee:ff/events',
      (server) => server.reply(200, [
        deviceEventJson(id: 1, scanner: 'Arp'),
        deviceEventJson(id: 2, scanner: 'Mdns'),
      ]),
    );

    final events = await BackendAPI.instance.getDeviceEvents(
      'aa:bb:cc:dd:ee:ff',
    );

    expect(events, hasLength(2));
    expect(events.first.scannerLabel, 'ARP');
  });

  test('getDeviceEvents sends created_from when provided', () async {
    final from = DateTime.utc(2026, 5, 1, 0, 0, 0);
    adapter.onGet(
      '/devices/aa:bb:cc:dd:ee:ff/events',
      (server) => server.reply(200, <dynamic>[]),
      queryParameters: {'created_from': from.toIso8601String()},
    );

    final events = await BackendAPI.instance.getDeviceEvents(
      'aa:bb:cc:dd:ee:ff',
      createdFrom: from,
    );

    expect(events, isEmpty);
  });
}
