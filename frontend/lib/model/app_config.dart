/// Front-end-facing backend configuration, served by `GET /api/config`.
///
/// Only the settings the UI needs to adapt itself are exposed. Today that is the
/// notification delivery method, which the settings screen uses to decide
/// whether the per-device push toggle applies.
class AppConfig {
  AppConfig({required this.notificationMethod});

  /// The backend's configured delivery method (e.g. `push`, `pushover`, `none`).
  final String notificationMethod;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final notifications = json['notifications'] as Map<String, dynamic>;
    return AppConfig(notificationMethod: notifications['method'] as String);
  }
}
