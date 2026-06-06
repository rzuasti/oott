/// Centralised route locations so navigation targets are defined once and
/// reused by both the router (see `navigation.dart`) and every call site.
abstract final class Routes {
  static const String home = '/';
  static const String devices = '/devices';
  static const String status = '/status';
  static const String settings = '/settings';
  static const String about = '/about';

  /// Path segment for the device-detail route, nested under [devices].
  static const String deviceDetailSegment = ':macAddress';

  /// Full location for a single device's detail page.
  static String deviceDetail(String macAddress) => '$devices/$macAddress';
}
