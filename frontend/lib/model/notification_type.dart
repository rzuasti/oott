import 'package:flutter/material.dart';

enum NotificationType {
  newDeviceFound,
  deviceOnlineAfterTime,
  deviceChanged,
  other;

  IconData get icon {
    switch (this) {
      case newDeviceFound:
        return Icons.radar;
      case deviceOnlineAfterTime:
        return Icons.timer;
      case deviceChanged:
        return Icons.change_circle;
      case other:
        return Icons.notification_important;
    }
  }

  static NotificationType fromString(String value) =>
      switch (value.toLowerCase()) {
        "newdevicefound" => newDeviceFound,
        "deviceonlineaftertime" => deviceOnlineAfterTime,
        "devicechanged" => deviceChanged,
        _ => other,
      };
}
