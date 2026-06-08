part of '../oott_api.dart';

/// Front-end configuration endpoint: the subset of backend settings the UI needs
/// to adapt itself (currently the notification delivery method).
extension ConfigApi on BackendAPI {
  /// Fetches the backend's UI-facing configuration. Used by the settings screen
  /// to show push controls only when the backend delivers via push.
  Future<AppConfig> getConfig() => _getModel('/config', AppConfig.fromJson);
}
