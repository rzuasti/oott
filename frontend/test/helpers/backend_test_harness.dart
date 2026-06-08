import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/backend_reachability.dart';
import 'package:frontend/utils/oott_api.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _connectivityMethodChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);
const _connectivityEventChannel = EventChannel(
  'dev.fluttercommunity.plus/connectivity_status',
);

bool _channelsStubbed = false;

/// Neutralises the connectivity_plus platform channels so the
/// [BackendReachability] singleton can be constructed in tests without the
/// plugin throwing `MissingPluginException`. `check` reports a network, and
/// the change stream stays open but emits nothing.
void _stubConnectivityChannels() {
  if (_channelsStubbed) return;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_connectivityMethodChannel, (call) async {
    if (call.method == 'check') return <String>['wifi'];
    return null;
  });
  messenger.setMockStreamHandler(
    _connectivityEventChannel,
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );
  _channelsStubbed = true;
}

/// Prepares the backend singletons for a test and returns a [DioAdapter] so the
/// test can stub HTTP routes. Call from `setUp`.
///
/// This (1) seeds mock SharedPreferences, (2) stubs the connectivity channels,
/// (3) forces [BackendReachability] online so polling widgets load, and
/// (4) swaps the [BackendAPI] singleton's Dio for one backed by a mock adapter.
///
/// `prefs` are only honoured on the first call within a test isolate, because
/// `PrefUtil` caches the SharedPreferences instance after its one-shot init.
/// Use [PrefUtil.setValue] for per-test changes after that.
Future<DioAdapter> setUpBackendForTest({
  Map<String, Object> prefs = const {},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _stubConnectivityChannels();

  SharedPreferences.setMockInitialValues({
    'base_url': 'http://test.local/api',
    'api_key': '',
    ...prefs,
  });
  await PrefUtil.init();

  BackendReachability.instance.forceOnlineForTesting();

  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'));
  final adapter = DioAdapter(dio: dio);
  BackendAPI.instance.dioForTesting = dio;
  // Keep the mock client even after a reconfigure (e.g. saving the backend
  // settings) so no test ever issues a real network request.
  BackendAPI.dioBuilderForTesting = (_, _) => dio;
  return adapter;
}
