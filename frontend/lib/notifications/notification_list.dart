import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';

class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  _NotificationListState createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  final _pagingController = PagingController<int, oott_model.Notification>(
    getNextPageKey: (state) => state.lastPageIsEmpty
        ? null
        : (state.items == null ? 0 : state.items?.length),
    fetchPage: (pageKey) => BackendAPI.instance.listNotifications(pageKey),
  );

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: PagingListener(
        controller: _pagingController,
        builder: (context, state, fetchNextPage) =>
            PagedListView<int, oott_model.Notification>(
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate(
                itemBuilder: (context, item, index) {
                  return Dismissible(
                    key: UniqueKey(),
                    onDismissed: (direction) {
                      setState(() {
                        // _events!.removeAt(index);
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
                      leading: Icon(item.notificationType.icon),
                      title: Text(
                        '${FriendlyDateFormatter().format(item.createdOn)} - ${item.title}',
                      ),
                      subtitle: Text(item.body),
                      trailing: Icon(Icons.more_vert),
                      onTap: () {},
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }
}
