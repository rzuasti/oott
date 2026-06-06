/// Shared placeholders for rendering values in the UI.
abstract final class Placeholders {
  /// Shown in place of a value that is absent or unknown (e.g. a device with no
  /// hostname, vendor, or determined type). An em dash reads better than a blank
  /// cell. The backend uses a plain hyphen in notifications for the same purpose.
  static const String emptyValue = '—';
}
