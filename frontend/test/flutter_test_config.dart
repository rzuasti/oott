import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Global test bootstrap, picked up automatically by `flutter test` for every
/// test under `test/`. Disables Google Fonts runtime fetching so no test can
/// accidentally hit the network for a font (tests render screens directly
/// rather than through the app shell, but this is a cheap safety net).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
