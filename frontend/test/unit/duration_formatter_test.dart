import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/duration_formatter.dart';

void main() {
  test('renders sub-minute values in seconds', () {
    expect(formatSeconds(0), '0s');
    expect(formatSeconds(59), '59s');
  });

  test('rounds fractional seconds to the nearest whole second', () {
    expect(formatSeconds(5.4), '5s');
    expect(formatSeconds(5.6), '6s');
  });

  test('renders minute-and-second values past 60 seconds', () {
    expect(formatSeconds(60), '1m 0s');
    expect(formatSeconds(125), '2m 5s');
  });

  test('rounding up to a full minute carries into the minutes part', () {
    expect(formatSeconds(59.6), '1m 0s');
  });

  test('clamps negative values to zero', () {
    expect(formatSeconds(-10), '0s');
  });
}
