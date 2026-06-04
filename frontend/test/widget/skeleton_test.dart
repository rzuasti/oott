import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/skeleton.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  setUp(() async {
    await setUpBackendForTest();
  });

  testWidgets('ListSkeleton renders three placeholder blocks per row', (
    tester,
  ) async {
    await pumpScreen(tester, const ListSkeleton(rows: 2));
    await tester.pump();

    // Each row is an avatar block plus two text-line blocks.
    expect(find.byType(Skeleton), findsNWidgets(6));

    // Unmount so the pulsing animation controllers are disposed cleanly.
    await tearDownTree(tester);
  });
}
