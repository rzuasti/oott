import 'package:flutter/material.dart';

enum DeviceType {
  phone,
  laptop,
  tablet,
  server,
  tv,
  printer,
  networkAppliance,
  homeSecurity,
  homeAppliance,
  watch,
  pc,
  gamingConsole,
  unknown;

  IconData get icon => switch (this) {
    phone => Icons.phone_android,
    laptop => Icons.laptop,
    tablet => Icons.tablet_android,
    server => Icons.dns,
    tv => Icons.tv,
    printer => Icons.print,
    networkAppliance => Icons.device_hub,
    homeSecurity => Icons.security,
    homeAppliance => Icons.kitchen,
    watch => Icons.watch,
    pc => Icons.computer,
    gamingConsole => Icons.sports_esports,
    unknown => Icons.question_mark,
  };

  String get label => switch (this) {
    tv => 'TV',
    pc => 'PC',
    _ =>
      name
          .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
          .trim()
          .split(' ')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' '),
  };

  String get apiName => switch (this) {
    networkAppliance => 'network_appliance',
    homeSecurity => 'home_security',
    homeAppliance => 'home_appliance',
    gamingConsole => 'gaming_console',
    _ => name,
  };

  static DeviceType fromString(String value) => switch (value.toLowerCase()) {
    'phone' => phone,
    'laptop' => laptop,
    'tablet' => tablet,
    'server' => server,
    'tv' => tv,
    'printer' => printer,
    'network_appliance' => networkAppliance,
    'home_security' => homeSecurity,
    'home_appliance' => homeAppliance,
    'watch' => watch,
    'pc' => pc,
    'gaming_console' => gamingConsole,
    _ => unknown,
  };
}
