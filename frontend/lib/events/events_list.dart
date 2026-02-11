import 'package:flutter/material.dart';
import 'package:frontend/utils/friendly_date_formatter.dart';
import '../model/event.dart';
import '../model/device_type.dart';

// Dummy events to display
// TODO : Replace with API call
final List<Event> events = <Event>[
  Event(
    id: 5,
    title: 'New device found',
    description: 'Apple device @ 192.168.0.1 with MAC 56:e7:e3:07:d2:d5',
    isRead: false,
    deviceType: DeviceType.phone,
    dateTime: DateTime.now().subtract(Duration(minutes: 22)),
  ),
  Event(
    id: 4,
    title: 'New device found',
    description: 'Apple device @ 192.168.0.1 with MAC 56:e7:e3:07:d2:d5',
    isRead: false,
    deviceType: DeviceType.pc,
    dateTime: DateTime.now().subtract(Duration(minutes: 87)),
  ),
  Event(
    id: 3,
    title: 'New device found',
    description: 'Apple device @ 192.168.0.1 with MAC 56:e7:e3:07:d2:d5',
    isRead: false,
    deviceType: DeviceType.tablet,
    dateTime: DateTime.now().subtract(Duration(hours: 23)),
  ),
  Event(
    id: 2,
    title: 'New device found',
    description: 'Apple device @ 192.168.0.1 with MAC 56:e7:e3:07:d2:d5',
    isRead: false,
    deviceType: DeviceType.server,
    dateTime: DateTime(2026, 01, 19, 14, 47),
  ),
  Event(
    id: 1,
    title: 'New device found',
    description: 'Apple device @ 192.168.0.1 with MAC 56:e7:e3:07:d2:d5',
    isRead: false,
    deviceType: DeviceType.phone,
    dateTime: DateTime(2026, 01, 17, 14, 47),
  ),
];

class EventsList extends StatelessWidget {
  const EventsList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: events.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(events[index].deviceType.icon),
          title: Text(
            '${FriendlyDateFormatter().format(events[index].dateTime)} - ${events[index].title}',
          ),
          subtitle: Text(events[index].description),
        );
      },
      separatorBuilder: (context, index) => Divider(),
    );
  }
}
