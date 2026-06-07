import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/local_network_permission.dart';

void main() {
  test('is a no-op off iOS and never throws', () async {
    // Tests run on the host VM (not iOS), so this exercises the guard: it must
    // return cleanly without touching the network or raising.
    await expectLater(requestLocalNetworkPermission(), completes);
  });
}
