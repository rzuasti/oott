class DeviceSummary {
  final int totalRegistered;
  final int seenLastDayRegistered;
  final int seenLastDayUnregistered;
  final int seenLastWeekRegistered;
  final int seenLastWeekUnregistered;

  const DeviceSummary({
    required this.totalRegistered,
    required this.seenLastDayRegistered,
    required this.seenLastDayUnregistered,
    required this.seenLastWeekRegistered,
    required this.seenLastWeekUnregistered,
  });

  DeviceSummary.fromJson(Map<String, dynamic> json)
    : totalRegistered = json['total_registered'] as int,
      seenLastDayRegistered = json['seen_last_day_registered'] as int,
      seenLastDayUnregistered = json['seen_last_day_unregistered'] as int,
      seenLastWeekRegistered = json['seen_last_week_registered'] as int,
      seenLastWeekUnregistered = json['seen_last_week_unregistered'] as int;
}
