import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/model/device_summary.dart';

import '../helpers/fixtures.dart';

void main() {
  test('DeviceSummary.fromJson maps every count field', () {
    final summary = DeviceSummary.fromJson(
      deviceSummaryJson(
        totalRegistered: 10,
        seenLastDayRegistered: 4,
        seenLastDayUnregistered: 2,
        seenLastWeekRegistered: 8,
        seenLastWeekUnregistered: 5,
      ),
    );

    expect(summary.totalRegistered, 10);
    expect(summary.seenLastDayRegistered, 4);
    expect(summary.seenLastDayUnregistered, 2);
    expect(summary.seenLastWeekRegistered, 8);
    expect(summary.seenLastWeekUnregistered, 5);
  });
}
