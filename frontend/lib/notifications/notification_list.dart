import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';
import '../utils/oott_api.dart';
import '../utils/ui_snackbars.dart';

enum _NotificationFilter {
  newOnly('New'),
  oldOnly('Old'),
  all('All');

  const _NotificationFilter(this.label);

  final String label;

  bool? get isNew => switch (this) {
    _NotificationFilter.newOnly => true,
    _NotificationFilter.oldOnly => false,
    _NotificationFilter.all => null,
  };
}

class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  _NotificationFilter _filter = _NotificationFilter.newOnly;
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
    fetchPage: (pageKey) =>
        BackendAPI.instance.listNotifications(_filter.isNew, pageKey),
  );

  Future<void> _markAllAsRead(BuildContext context) async {
    await BackendAPI.instance.markAllNotificationsAsRead();
    _pagingController.refresh();
    if (context.mounted) {
      UISnackbars.showSuccess(context, 'All notifications marked as read');
    }
  }

  Future<bool> _setRead(
    BuildContext context,
    oott_model.Notification item,
    bool read,
  ) async {
    if (item.isNew == !read) {
      UISnackbars.showWarning(
        context,
        'Notification was already marked as ${read ? 'read' : 'unread'}',
      );
      return false;
    }
    if (read) {
      await BackendAPI.instance.markNotificationAsRead(item.id);
    } else {
      await BackendAPI.instance.markNotificationAsNew(item.id);
    }
    if (!context.mounted) return false;
    UISnackbars.showSuccess(
      context,
      'Event marked as ${read ? 'read' : 'unread'}',
    );
    if (_filter != _NotificationFilter.all) {
      _pagingController.value = _pagingController.value.filterItems(
        (n) => n.id != item.id,
      );
      return true;
    }
    _pagingController.mapItems(
      (n) => n.id == item.id ? n.copyWith(isNew: !read) : n,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = FriendlyDateFormatter();

    return PagingListener(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (_filter == _NotificationFilter.newOnly &&
                (state.items?.isNotEmpty ?? false))
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
                  children: _NotificationFilter.values
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) {
                            setState(() => _filter = f);
                            _pagingController.refresh();
                          },
                        ),
                      )
                      .toList(),
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
                itemBuilder: (context, item, index) => _NotificationCard(
                  item: item,
                  formatter: formatter,
                  onSetRead: (ctx, read) => _setRead(ctx, item, read),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pagingController.dispose();
    super.dispose();
  }
}

class _NotificationCard extends StatelessWidget {
  final oott_model.Notification item;
  final FriendlyDateFormatter formatter;
  final Future<bool> Function(BuildContext, bool read) onSetRead;

  const _NotificationCard({
    required this.item,
    required this.formatter,
    required this.onSetRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: item.isNew ? theme.colorScheme.secondaryContainer : null,
      child: Dismissible(
        key: UniqueKey(),
        confirmDismiss: (direction) => direction == DismissDirection.startToEnd
            ? onSetRead(context, false)
            : onSetRead(context, true),
        background: Container(
          color: theme.colorScheme.tertiaryContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.mark_email_unread),
        ),
        secondaryBackground: Container(
          color: theme.colorScheme.primaryContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.done),
        ),
        child: ListTile(
          leading: Icon(
            item.notificationType.icon,
            color: item.isNew ? theme.colorScheme.primary : null,
          ),
          title: Text(
            '${formatter.format(item.createdOn)} - ${item.title}',
            style: item.isNew
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
          subtitle: Text(item.body, maxLines: 5),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'view_device') {
                if (item.isNew) await onSetRead(context, true);
                if (context.mounted) {
                  context.push('/devices/${item.macAddress}');
                }
              } else if (value == 'mark_read') {
                await onSetRead(context, true);
              } else if (value == 'mark_new') {
                await onSetRead(context, false);
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
                  if (item.isNew) await onSetRead(context, true);
                  if (context.mounted) {
                    context.push('/devices/${item.macAddress}');
                  }
                }
              : null,
          isThreeLine: true,
        ),
      ),
    );
  }
}
