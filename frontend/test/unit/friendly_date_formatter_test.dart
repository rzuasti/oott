import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/friendly_date_formatter.dart';

void main() {
  final formatter = FriendlyDateFormatter();
  final now = DateTime.now();

  test('renders very recent times as "Just now"', () {
    expect(formatter.format(now.subtract(const Duration(seconds: 30))), 'Just now');
    expect(formatter.format(now.subtract(const Duration(minutes: 2))), 'Just now');
  });

  test('renders times under an hour as relative minutes', () {
    expect(
      formatter.format(now.subtract(const Duration(minutes: 30))),
      '30 minutes ago',
    );
  });

  test('renders earlier-today / late-yesterday times with a clock time', () {
    final candidate = now.subtract(const Duration(hours: 2));
    final sameDay = candidate.year == now.year &&
        candidate.month == now.month &&
        candidate.day == now.day;

    expect(
      formatter.format(candidate),
      startsWith(sameDay ? 'Today at' : 'Yesterday at'),
    );
  });

  test('renders a yesterday-noon time as "Yesterday at"', () {
    final yesterdayNoon =
        DateTime(now.year, now.month, now.day - 1, 12, 0);

    expect(formatter.format(yesterdayNoon), startsWith('Yesterday at'));
  });

  test('renders older dates with the full date', () {
    final threeDaysAgo = DateTime(now.year, now.month, now.day - 3, 12, 0);
    final result = formatter.format(threeDaysAgo);

    expect(result, contains(threeDaysAgo.year.toString()));
    expect(result, isNot(startsWith('Today')));
    expect(result, isNot(startsWith('Yesterday')));
  });
}
