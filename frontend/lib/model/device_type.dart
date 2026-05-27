import 'package:flutter/material.dart';

enum DeviceType {
  phone,
  laptop,
  tablet,
  server,
  router,
  tv,
  printer,
  unknown;

  IconData get icon => switch (this) {
    phone => Icons.phone_android,
    laptop => Icons.laptop,
    tablet => Icons.tablet_android,
    server => Icons.dns,
    router => Icons.router,
    tv => Icons.tv,
    printer => Icons.print,
    unknown => Icons.device_unknown,
  };

  String get label =>
      this == unknown ? 'Unknown' : name[0].toUpperCase() + name.substring(1);

  static DeviceType fromString(String value) => switch (value.toLowerCase()) {
    'phone' => phone,
    'laptop' => laptop,
    'tablet' => tablet,
    'server' => server,
    'router' => router,
    'tv' => tv,
    'printer' => printer,
    _ => unknown,
  };
}
