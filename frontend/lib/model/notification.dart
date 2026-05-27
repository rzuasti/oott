import 'notification_type.dart';

class Notification {
  int id;
  String title;
  String body;
  bool isNew;
  NotificationType notificationType;
  DateTime createdOn;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.createdOn,
    this.isNew = true,
  });

  Notification.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      createdOn = DateTime.parse(json['created_on'] as String),
      notificationType = NotificationType.fromString(
        json['notification_type'] as String,
      ),
      title = json['title'] as String,
      body = json['body'] as String,
      isNew = json['is_new'] as bool;

  Notification copyWith({bool? isNew}) => Notification(
    id: id,
    title: title,
    body: body,
    notificationType: notificationType,
    createdOn: createdOn,
    isNew: isNew ?? this.isNew,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_on': createdOn.toUtc().toIso8601String(),
    'notification_type': notificationType.toString,
    'title': title,
    'body': body,
    'is_new': isNew,
  };
}
