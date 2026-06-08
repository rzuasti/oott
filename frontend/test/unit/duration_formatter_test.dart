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

  test('renders hour-and-minute values past 60 minutes', () {
    expect(formatSeconds(3600), '1h 0m');
    expect(formatSeconds(3600 + 125), '1h 2m');
  });

  test('renders day-and-hour values past 24 hours', () {
    expect(formatSeconds(86400), '1d 0h');
    expect(formatSeconds(86400 + 3 * 3600), '1d 3h');
  });

  test('renders week-and-day values past 7 days', () {
    expect(formatSeconds(604800), '1w 0d');
    expect(formatSeconds(604800 + 2 * 86400), '1w 2d');
  });

  test('renders month-and-week values past 30 days', () {
    expect(formatSeconds(2592000), '1mo 0w');
    expect(formatSeconds(2592000 + 14 * 86400), '1mo 2w');
  });

  test('clamps negative values to zero', () {
    expect(formatSeconds(-10), '0s');
  });
}
