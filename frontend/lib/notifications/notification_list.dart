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
  int _filterChoice = 1; // 1 => Only new, 2=> Only old, 3=> All

  late final _pagingController = PagingController<int, oott_model.Notification>(
    getNextPageKey: (state) => state.lastPageIsEmpty
        ? null
        : (state.items == null ? 0 : state.items?.length),
    fetchPage: (pageKey) {
      bool? isNew;

      if (_filterChoice == 1) {
        isNew = true;
      } else if (_filterChoice == 2) {
        isNew = false;
      }

      return BackendAPI.instance.listNotifications(isNew, pageKey);
    },
  );

  Future<bool> _markAsRead(
    BuildContext context,
    oott_model.Notification item,
  ) async {
    if (!item.isNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification was already marked as read'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
      return false;
    }
    await BackendAPI.instance.markNotificationAsRead(item.id);
    _pagingController.value = _pagingController.value.filterItems(
      (n) => n.id != item.id,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Event marked as read'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body:
          // Paginated list start
          PagingListener(
            controller: _pagingController,
            builder: (context, state, fetchNextPage) => CustomScrollView(
              slivers: [
                // Filters go here
                SliverToBoxAdapter(
                  child: Container(
                    height: 50,
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: Text('New'),
                          selected: _filterChoice == 1,
                          onSelected: (bool selected) {
                            _filterChoice = 1;
                            _pagingController.refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text('Old'),
                          selected: _filterChoice == 2,
                          onSelected: (bool selected) {
                            _filterChoice = 2;
                            _pagingController.refresh();
                          },
                        ),
                        ChoiceChip(
                          label: Text('All'),
                          selected: _filterChoice == 3,
                          onSelected: (bool selected) {
                            _filterChoice = 3;
                            _pagingController.refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                PagedSliverList<int, oott_model.Notification>(
                  state: state,
                  fetchNextPage: fetchNextPage,
                  builderDelegate: PagedChildBuilderDelegate(
                    itemBuilder: (context, item, index) {
                      return Column(
                        children: [
                          Dismissible(
                            key: UniqueKey(),
                            confirmDismiss: (direction) =>
                                _markAsRead(context, item),
                            background: Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              alignment: Alignment.center,
                              child: Icon(Icons.done),
                            ),
                            child: ListTile(
                              // tileColor: item.isNew ? Colors.amber : null,
                              leading: Icon(item.notificationType.icon),
                              title: Text(
                                '${FriendlyDateFormatter().format(item.createdOn)} - ${item.title}',
                              ),
                              subtitle: Text(item.body, maxLines: 5),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'mark_read') {
                                    await _markAsRead(context, item);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (item.isNew)
                                    const PopupMenuItem(
                                      value: 'mark_read',
                                      child: Text('Mark as read'),
                                    ),
                                ],
                              ),
                              onTap: () {},
                              isThreeLine: true,
                            ),
                          ),
                          Divider(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
    // Paginated list end
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}
