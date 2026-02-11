import 'device_type.dart';

class Event {
  int id;
  String title;
  String description;
  bool isRead;
  DeviceType deviceType;
  DateTime dateTime;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.deviceType,
    required this.dateTime,
    this.isRead = false,
  });
}
