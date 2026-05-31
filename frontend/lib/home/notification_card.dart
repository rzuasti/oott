import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/notification.dart' as oott_model;
import '../utils/friendly_date_formatter.dart';

class NotificationCard extends StatelessWidget {
  final oott_model.Notification item;
  final FriendlyDateFormatter formatter;
  final Future<bool> Function(bool read) onSetRead;

  const NotificationCard({
    required this.item,
    required this.formatter,
    required this.onSetRead,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: item.isNew ? theme.colorScheme.secondaryContainer : null,
      child: Dismissible(
        key: ValueKey(item.id),
        confirmDismiss: (direction) =>
            onSetRead(direction != DismissDirection.startToEnd),
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
                if (item.isNew) await onSetRead(true);
                if (context.mounted) {
                  context.push('/devices/${item.macAddress}');
                }
              } else if (value == 'mark_read') {
                await onSetRead(true);
              } else if (value == 'mark_new') {
                await onSetRead(false);
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
                  if (item.isNew) await onSetRead(true);
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
