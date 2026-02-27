import 'package:flutter/material.dart';
import '../utils/friendly_date_formatter.dart';
import '../model/event.dart';
import '../utils/oott_api.dart';

class EventsList extends StatefulWidget {
  @override
  _EventListState createState() => _EventListState();
}

class _EventListState extends State<EventsList> {
  bool _isLoading = true;
  List<Event>? _events;

  @override
  void initState() {
    super.initState();
    _getData();
  }

  void _getData() async {
    _events = await BackendAPI.instance.listNotifications();
    _isLoading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _events!.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: UniqueKey(),
                  onDismissed: (direction) {
                    setState(() {
                      _events!.removeAt(index);
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
                    leading: Icon(_events![index].notificationType.icon),
                    title: Text(
                      '${FriendlyDateFormatter().format(_events![index].createdOn)} - ${_events![index].title}',
                    ),
                    subtitle: Text(_events![index].body),
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
