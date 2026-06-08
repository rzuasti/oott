import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'oott_api.dart';

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
  FirebasePushService({FlutterLocalNotificationsPlugin? localNotifications})
    : _localNotifications =
          localNotifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _localNotifications;

  // Android channel used to surface a heads-up notification while the app is in
  // the foreground (the OS shows backgrounded/terminated notifications itself).
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'oott_alerts',
        'OOTT alerts',
        description:
            'New device, device back online and device changed alerts.',
        importance: Importance.high,
      );

  bool _foregroundDisplayWired = false;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Future<void> _ensureFirebase() async {
    // No options passed: the native google-services.json / GoogleService-Info
    // .plist added during the one-time project setup provide them.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  @override
  Future<bool> enable() async {
    if (!isSupported) return false;
    await _ensureFirebase();

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return false;

    await BackendAPI.instance.registerPushToken(token, _platformName);

    // Re-register whenever FCM rotates the token so the backend never holds a
    // stale one.
    FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
      BackendAPI.instance.registerPushToken(refreshed, _platformName);
    });

    await _wireForegroundDisplay();
    return true;
  }

  @override
  Future<void> disable() async {
    if (!isSupported) return;
    await _ensureFirebase();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await BackendAPI.instance.unregisterPushToken(token);
    }
    await FirebaseMessaging.instance.deleteToken();
  }

  // Configure the local-notifications plugin and render foreground messages
  // ourselves (the OS displays them directly when the app is backgrounded or
  // terminated). Taps just open the app, so no tap handler is wired.
  Future<void> _wireForegroundDisplay() async {
    if (_foregroundDisplayWired) return;
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
}
