part of '../oott_api.dart';

/// Push-token endpoints: register/refresh this device's FCM token so the backend
/// can deliver push notifications to it, and unregister it when push is disabled.
///
/// Only the opaque FCM token and the platform travel here — no device or network
/// data. The token is a credential, so the unregister path component is encoded.
extension PushApi on BackendAPI {
  /// Registers or refreshes [token] for [platform] (`android` or `ios`). Safe to
  /// call repeatedly (e.g. on launch or after an FCM token refresh): the backend
  /// upserts by token.
  Future<void> registerPushToken(String token, String platform) async {
    await _dio.put(
      '/push_tokens',
      data: {'token': token, 'platform': platform},
    );
  }

  /// Unregisters [token] so this device stops receiving push notifications.
  /// Idempotent: unregistering an unknown token still succeeds.
  Future<void> unregisterPushToken(String token) async {
    await _dio.delete('/push_tokens/${Uri.encodeComponent(token)}');
  }
}
