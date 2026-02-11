import 'package:flutter/material.dart';
import 'package:frontend/utils/friendly_date_formatter.dart';
import '../model/event.dart';
import '../model/device_type.dart';

class EventsList extends StatefulWidget {
  @override
  _EventListState createState() => _EventListState();
}

class _EventListState extends State<EventsList> {
  // Dummy events to display
  // TODO : Replace with API call
  List<Event> events = <Event>[
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: ListView.separated(
        itemCount: events.length,
        itemBuilder: (context, index) {
          return Dismissible(
            key: UniqueKey(),
            onDismissed: (direction) {
              setState(() {
                events.removeAt(index);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Event marked as read'),
                  behavior: SnackBarBehavior.floating,
                  showCloseIcon: true,
                ),
              );
            },
            background: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              alignment: Alignment.center,
              child: Icon(Icons.done),
            ),
            child: ListTile(
              leading: Icon(events[index].deviceType.icon),
              title: Text(
                '${FriendlyDateFormatter().format(events[index].dateTime)} - ${events[index].title}',
              ),
              subtitle: Text(events[index].description),
              trailing: Icon(Icons.more_vert),
              onTap: () {},
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(),
      ),
    );
  }
}
