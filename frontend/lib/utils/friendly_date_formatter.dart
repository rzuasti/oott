import 'package:intl/intl.dart';

class FriendlyDateFormatter {
  FriendlyDateFormatter();

  String format(DateTime dateTime) {
    DateTime now = DateTime.now();
    Duration timeSince = now.difference(dateTime);
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    DateTime dateTimeWithoutTime = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    if (timeSince.inMinutes < 60) return '${timeSince.inMinutes} minutes ago';
    if (dateTimeWithoutTime == today) {
      return 'Today at ${DateFormat.Hm().format(dateTime)}';
    }
    if (dateTimeWithoutTime == yesterday) {
      return 'Yesterday at ${DateFormat.Hm().format(dateTime)}';
    }

    return DateFormat.yMMMMd().add_Hm().format(dateTime);
  }
}
