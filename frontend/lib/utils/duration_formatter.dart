/// Formats a duration given in [seconds] into a compact, human-readable string.
///
/// The format scales with the magnitude of the duration, always showing the two
/// largest relevant units: seconds for sub-minute spans, then minutes, hours,
/// days, weeks and finally months for longer ones.
String formatSeconds(double seconds) {
  final total = seconds.round().clamp(0, double.maxFinite.toInt());
  const minute = 60;
  const hour = 60 * minute;
  const day = 24 * hour;
  const week = 7 * day;
  const month = 30 * day;

  if (total < minute) return '${total}s';
  if (total < hour) return '${total ~/ minute}m ${total % minute}s';
  if (total < day) return '${total ~/ hour}h ${(total % hour) ~/ minute}m';
  if (total < week) return '${total ~/ day}d ${(total % day) ~/ hour}h';
  if (total < month) return '${total ~/ week}w ${(total % week) ~/ day}d';
  return '${total ~/ month}mo ${(total % month) ~/ week}w';
}
