import 'package:flutter/material.dart';
import 'package:frontend/theme/catppuccin_mocha_theme.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:provider/provider.dart';
import 'navigation.dart';
import 'theme/gruvbox_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefUtil.init();
  runApp(const MainApp());
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
    final saved = PrefUtil.getValue('theme', 'catppuccin_mocha') as String;
    _themeKey = _themes.containsKey(saved) ? saved : 'catppuccin_mocha';
  }

  late String _themeKey;
  String get themeKey => _themeKey;
  ThemeData get theme => _themes[_themeKey]!;

  void setTheme(String key) {
    if (!_themes.containsKey(key) || key == _themeKey) return;
    _themeKey = key;
    PrefUtil.setValue('theme', key);
    notifyListeners();
  }
}
