import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'oott_api.dart';
import 'pref_utils.dart';

// Whether push is available on this platform/build (mobile only — FCM/APNs).
bool get _pushSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String get _platformName => _isIOS ? 'ios' : 'android';

// --------------------------------------------------------------------------
// Persisted per-device intent
// --------------------------------------------------------------------------

/// Whether the user has turned push on for this device (persisted intent). Owned
/// here so the storage key lives in one place; the delivery wiring keys off this.
bool get pushEnabledOnThisDevice =>
    PrefUtil.getValue('push_enabled', false) as bool;

/// Persists the per-device push intent. See [pushEnabledOnThisDevice].
Future<void> setPushEnabledOnThisDevice({required bool enabled}) =>
    PrefUtil.setValue('push_enabled', enabled);

// --------------------------------------------------------------------------
// iOS APNs diagnostics
// --------------------------------------------------------------------------

// Channel exposing the native iOS APNs registration outcome (see AppDelegate).
const MethodChannel _pushDiagnosticsChannel = MethodChannel(
  'oott/push_diagnostics',
);

/// Reads the most recent native iOS APNs registration outcome for in-app
/// diagnostics, since reading the device console requires a Mac. Returns a short
/// status string on iOS, or null elsewhere or when the channel is unavailable
/// (e.g. in tests).
Future<String?> apnsRegistrationStatus() async {
  if (!_isIOS) return null;
  try {
    return await _pushDiagnosticsChannel.invokeMethod<String>('apnsStatus');
  } catch (_) {
    return null;
  }
}

// --------------------------------------------------------------------------
// App-launch wiring
// --------------------------------------------------------------------------

/// Resumes push on app launch. Always configures Firebase (required at launch so
/// the firebase_messaging plugin can forward the iOS APNs token to FCM), then,
/// when push is already enabled on this device, re-attaches the foreground
/// display handler and re-registers the current token so the backend converges to
/// the live token even if it rotated or the backend lost its token store. Single
/// startup entry point, so callers need no knowledge of push internals.
Future<void> initPushOnLaunch() async {
  await _initFirebase();
  if (!pushEnabledOnThisDevice) return;
  await _ensureForegroundDisplay();
  await _registerCurrentToken();
}

// Initializes Firebase on push-capable platforms. No-op on web/desktop and if
// Firebase is already initialized. Options come from the committed
// firebase_options.dart, so no google-services.json / GoogleService-Info.plist
// is needed in the build.
Future<void> _initFirebase() async {
  if (!_pushSupported || Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// --------------------------------------------------------------------------
// Foreground display
// --------------------------------------------------------------------------

// Android channel used to surface a heads-up notification while the app is in the
// foreground (the OS shows backgrounded/terminated notifications itself).
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'oott_alerts',
  'OOTT alerts',
  description: 'New device, device back online and device changed alerts.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// Process-global so the foreground handler is wired at most once, whether the
// request comes from startup (push already enabled) or from enable() on toggle.
bool _foregroundDisplayWired = false;

// Renders push notifications that arrive while the app is in the foreground (the
// OS displays backgrounded/terminated ones itself); taps just open the app, so no
// tap handler is wired. Idempotent; a no-op on platforms without push.
Future<void> _ensureForegroundDisplay() async {
  if (!_pushSupported || _foregroundDisplayWired) return;
  _foregroundDisplayWired = true;

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_androidChannel);

  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  });
}

// --------------------------------------------------------------------------
// Token registration
// --------------------------------------------------------------------------

// Process-global so the FCM token-rotation listener is attached at most once,
// whether registration is driven from startup or from enable().
bool _tokenRefreshWired = false;

// Fetches this device's current FCM token, (re)registers it with the backend, and
// keeps it in sync when FCM rotates it. Assumes notification permission is already
// granted; returns false when no token is available (e.g. the iOS APNs token
// never arrived) or on platforms without push.
Future<bool> _registerCurrentToken() async {
  if (!_pushSupported) return false;
  await _initFirebase();

  // iOS: getToken() throws until Apple delivers the APNs token, so wait for it.
  if (_isIOS && !await _awaitApnsToken()) return false;

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return false;
  await BackendAPI.instance.registerPushToken(token, _platformName);

  if (!_tokenRefreshWired) {
    _tokenRefreshWired = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
      BackendAPI.instance.registerPushToken(refreshed, _platformName);
    });
  }
  return true;
}

// Polls for the iOS APNs token, which Apple delivers asynchronously after the
// user grants permission. Returns true once available, or false after a short
// bounded wait (e.g. no network on first run).
Future<bool> _awaitApnsToken() async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (await FirebaseMessaging.instance.getAPNSToken() != null) return true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return false;
}

// --------------------------------------------------------------------------
// Service
// --------------------------------------------------------------------------

/// Per-device push enable/disable, behind an interface so the settings UI can be
/// driven by a fake in tests without pulling in Firebase. Tapping a push only
/// opens the app (no deep-link, no identifier); the in-app notification list
/// holds the detail.
abstract class PushService {
  /// Whether push is available on this platform/build (mobile only — FCM/APNs).
  bool get isSupported;

  /// Requests notification permission, obtains the FCM token, and registers it
  /// with the backend. Returns true when push is enabled, false when the user
  /// declined permission or no token could be obtained.
  Future<bool> enable();

  /// Unregisters this device's token from the backend and clears it locally so
  /// the device stops receiving push notifications.
  Future<void> disable();
}

/// FCM-backed [PushService]. Kept separate from the UI so its Firebase
/// dependencies never reach widget tests, which use a fake [PushService].
class FirebasePushService implements PushService {
  @override
  bool get isSupported => _pushSupported;

  @override
  Future<bool> enable() async {
    if (!_pushSupported) return false;
    // Firebase must be configured before requesting permission on iOS.
    await _initFirebase();

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    // Obtain and register the token (waits for the iOS APNs token internally);
    // false means no token could be minted, so the toggle stays off.
    if (!await _registerCurrentToken()) return false;

    await _ensureForegroundDisplay();
    return true;
  }

  @override
  Future<void> disable() async {
    if (!_pushSupported) return;
    await _initFirebase();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await BackendAPI.instance.unregisterPushToken(token);
    }
    await FirebaseMessaging.instance.deleteToken();
  }
}
