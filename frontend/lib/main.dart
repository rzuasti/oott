import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/theme/catppuccin_mocha_theme.dart';
import 'package:frontend/utils/local_network_permission.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:frontend/utils/push_service.dart';
import 'package:provider/provider.dart';
import 'navigation.dart';
import 'theme/gruvbox_theme.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught platform error: $error\n$stack');
        return true;
      };

      try {
        await PrefUtil.init();
      } catch (e, stack) {
        debugPrint(
          'PrefUtil.init failed, continuing with defaults: $e\n$stack',
        );
      }

      // Initialize Firebase at launch so the firebase_messaging plugin's iOS
      // APNs swizzling has a configured app to forward the device token to;
      // without this getAPNSToken() never resolves and enabling push fails.
      try {
        await initFirebaseForPush();
      } catch (e, stack) {
        debugPrint('Firebase init for push failed, continuing: $e\n$stack');
      }

      // Settle iOS's local-network permission now, at launch, so it isn't
      // still being decided when the user first taps "Test" in settings.
      unawaited(requestLocalNetworkPermission());

      runApp(const MainApp());
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}

final class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp.router(
          title: 'OOTT',
          theme: appState.theme,
          routerConfig: router,
        ),
      ),
    );
  }
}

final _themes = {
  'catppuccin_mocha': catppuccinMochaDarkTheme,
  'gruvbox_dark': gruvboxDarkTheme,
};

class AppState extends ChangeNotifier {
  AppState() {
    final saved = PrefUtil.getValue('theme', 'gruvbox_dark') as String;
    _themeKey = _themes.containsKey(saved) ? saved : 'gruvbox_dark';
  }

  late String _themeKey;
  String get themeKey => _themeKey;
  ThemeData get theme => _themes[_themeKey]!;

  Future<bool> setTheme(String key) async {
    if (!_themes.containsKey(key)) return false;
    if (key == _themeKey) return true;
    _themeKey = key;
    notifyListeners();
    return PrefUtil.setValue('theme', key);
  }
}
