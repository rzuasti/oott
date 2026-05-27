import 'package:shared_preferences/shared_preferences.dart';

class PrefUtil {
  static late final SharedPreferences preferences;
  static bool _init = false;
  static Future init() async {
    if (_init) return;
    preferences = await SharedPreferences.getInstance();
    _init = true;
    return preferences;
  }

  static void setValue(String key, Object value) {
    switch (value) {
      case String s:
        preferences.setString(key, s);
      case bool b:
        preferences.setBool(key, b);
      case int i:
        preferences.setInt(key, i);
      default:
    }
  }

  static Object getValue(String key, Object defaultValue) {
    switch (defaultValue) {
      case String _:
        return preferences.getString(key) ?? defaultValue;
      case bool _:
        return preferences.getBool(key) ?? defaultValue;
      case int _:
        return preferences.getInt(key) ?? defaultValue;
      default:
        return defaultValue;
    }
  }
}
