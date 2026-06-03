import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/oott_api.dart';

void main() {
  // BackendAPI.test() builds its own Dio internally (no injectable seam), so
  // only its error-mapping path is testable here: an unresolvable host must
  // come back as a non-null, user-facing message rather than throwing. The
  // success path is a documented coverage gap.
  test('BackendAPI.test returns a user message for an unreachable backend',
      () async {
    // Loopback port 1 is closed: connection is refused immediately, keeping the
    // test hermetic (no DNS, no TLS, no traffic leaving the machine).
    final result = await BackendAPI.test('http://127.0.0.1:1/api', '');

    expect(result, isNotNull);
    expect(result, isNotEmpty);
  });
}
