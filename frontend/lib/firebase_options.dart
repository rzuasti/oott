// Firebase client configuration for the OOTT app, used by push notifications.
//
// These values are client identifiers (project id, sender id, app id, and a
// client API key). They are not secrets: they ship inside every distributed app
// binary and are fully extractable. Sending pushes requires the relay's
// server-side credential (which never leaves Google), and relay abuse is bounded
// by FCM project scoping + per-IP rate limiting + the billing cap. See
// push_notifications.md.
//
// Mirrors the shape FlutterFire's `flutterfire configure` generates, but only
// the platforms OOTT delivers push to (Android, iOS) are configured.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Push notifications are not configured for web; this should never be '
        'called there (see PushService.isSupported).',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD6R22FPkZarDIZymszuzASDCjvIONts1U',
    appId: '1:607706370042:android:39c9d29bfcdd385cf4de43',
    messagingSenderId: '607706370042',
    projectId: 'oott-push',
    storageBucket: 'oott-push.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCvDyPJJYW8JLKBdxdlCGsT-Y2nWfv7Gzs',
    appId: '1:607706370042:ios:43768238f07348f8f4de43',
    messagingSenderId: '607706370042',
    projectId: 'oott-push',
    storageBucket: 'oott-push.firebasestorage.app',
    iosBundleId: 'net.oott-security.app',
  );
}
