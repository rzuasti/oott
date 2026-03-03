import 'package:flutter/material.dart';
import 'package:frontend/utils/pref_utils.dart';
import 'package:provider/provider.dart';
import 'navigation.dart';

void main() async {
  PrefUtil.init();
  runApp(const MainApp());
}

final class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp.router(
        title: 'OOTT',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color.fromARGB(255, 214, 93, 14),
            brightness: Brightness.dark,
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  // Global app state goes here
}
