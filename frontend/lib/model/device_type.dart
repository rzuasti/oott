import 'package:flutter/material.dart';

enum DeviceType {
  phone,
  pc,
  tablet,
  server;

  IconData get icon {
    switch (this) {
      case phone:
        return Icons.phone_iphone;
      case pc:
        return Icons.computer;
      case tablet:
        return Icons.tablet;
      case server:
        return Icons.storage;
      default:
        return Icons.device_unknown;
    }
  }
}
