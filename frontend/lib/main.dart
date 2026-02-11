import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp.router(
        title: 'OOTT',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
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
