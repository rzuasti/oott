import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';

class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  int _filterChoice = 1; // 1 => Only new, 2=> Only old, 3=> All
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pagingController.refresh(),
    );
  }

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

  Future<void> _markAllAsRead(BuildContext context) async {
    await BackendAPI.instance.markAllNotificationsAsRead();
    _pagingController.refresh();
    if (context.mounted) {
      UISnackbars.showSuccess(context, 'All notifications marked as read');
    }
  }

  Future<bool> _markAsRead(
    BuildContext context,
    oott_model.Notification item,
  ) async {
    if (!item.isNew) {
      UISnackbars.showWarning(
        context,
        'Notification was already marked as read',
      );
      return false;
    }
    await BackendAPI.instance.markNotificationAsRead(item.id);
    if (!context.mounted) return false;
    UISnackbars.showSuccess(context, 'Event marked as read');
    if (_filterChoice != 3) {
      _pagingController.value = _pagingController.value.filterItems(
        (n) => n.id != item.id,
      );
      return true;
    }
    _pagingController.mapItems(
      (n) => n.id == item.id ? n.copyWith(isNew: false) : n,
    );
    return false;
  }

  Future<bool> _markAsNew(
    BuildContext context,
    oott_model.Notification item,
  ) async {
    if (item.isNew) {
      UISnackbars.showWarning(
        context,
        'Notification was already marked as unread',
      );
      return false;
    }
    await BackendAPI.instance.markNotificationAsNew(item.id);
    if (!context.mounted) return false;
    UISnackbars.showSuccess(context, 'Event marked as unread');
    if (_filterChoice != 3) {
      _pagingController.value = _pagingController.value.filterItems(
        (n) => n.id != item.id,
      );
      return true;
    }
    _pagingController.mapItems(
      (n) => n.id == item.id ? n.copyWith(isNew: true) : n,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Paginated list start
    return PagingListener(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (_filterChoice == 1 && (state.items?.isNotEmpty ?? false))
              IconButton(
                onPressed: () => _markAllAsRead(context),
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text('New'),
                      selected: _filterChoice == 1,
                      onSelected: (bool selected) {
                        _filterChoice = 1;
                        _pagingController.refresh();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Old'),
                      selected: _filterChoice == 2,
                      onSelected: (bool selected) {
                        _filterChoice = 2;
                        _pagingController.refresh();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('All'),
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
          ),
        ),
        body: CustomScrollView(
          slivers: [
            PagedSliverList<int, oott_model.Notification>(
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate(
                itemBuilder: (context, item, index) {
                  return Card(
                    color: item.isNew
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    child: Dismissible(
                        key: UniqueKey(),
                        confirmDismiss: (direction) =>
                            direction == DismissDirection.startToEnd
                            ? _markAsNew(context, item)
                            : _markAsRead(context, item),
                        background: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: Icon(Icons.mark_email_unread),
                        ),
                        secondaryBackground: Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(Icons.done),
                        ),
                        child: ListTile(
                          leading: Icon(
                            item.notificationType.icon,
                            color: item.isNew
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            '${FriendlyDateFormatter().format(item.createdOn)} - ${item.title}',
                            style: item.isNew
                                ? const TextStyle(fontWeight: FontWeight.bold)
                                : null,
                          ),
                          subtitle: Text(item.body, maxLines: 5),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'view_device') {
                                if (item.isNew) await _markAsRead(context, item);
                                if (context.mounted) context.push('/devices/${item.macAddress}');
                              } else if (value == 'mark_read') {
                                await _markAsRead(context, item);
                              } else if (value == 'mark_new') {
                                await _markAsNew(context, item);
                              }
                            },
                            itemBuilder: (context) => [
                              if (item.macAddress != null)
                                const PopupMenuItem(
                                  value: 'view_device',
                                  child: Text('View device'),
                                ),
                              if (item.isNew)
                                const PopupMenuItem(
                                  value: 'mark_read',
                                  child: Text('Mark as read'),
                                ),
                              if (!item.isNew)
                                const PopupMenuItem(
                                  value: 'mark_new',
                                  child: Text('Mark as unread'),
                                ),
                            ],
                          ),
                          onTap: item.macAddress != null
                              ? () async {
                                  if (item.isNew) await _markAsRead(context, item);
                                  if (context.mounted) context.push('/devices/${item.macAddress}');
                                }
                              : null,
                          isThreeLine: true,
                        ),
                      ),
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
    _refreshTimer?.cancel();
    _pagingController.dispose();
    super.dispose();
  }
}
