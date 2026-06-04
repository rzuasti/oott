import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/about/about.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  setUp(() async {
    await setUpBackendForTest();
  });

  testWidgets('renders the about content and release fallback', (tester) async {
    await pumpScreen(tester, const About());
    // PackageInfo.fromPlatform() has no plugin in tests, so the FutureBuilder
    // falls back to the hard-coded release date.
    await tester.pump();

    // The screen title now lives in the shared shell AppBar, not the body.
    // Assert the fallback prefix only, not the release date literal (it changes
    // every release).
    expect(find.textContaining('Released'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('openssl'), findsOneWidget);
  });
}
