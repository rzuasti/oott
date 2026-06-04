import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/notification.dart' as oott_model;
import '../theme/dimens.dart';
import '../utils/friendly_date_formatter.dart';

class NotificationCard extends StatefulWidget {
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
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _expanded = false;

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, Insets.sm),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => widget.onSetRead(widget.item.isNew),
            child: Text(widget.item.isNew ? 'Mark as read' : 'Mark as unread'),
          ),
          if (widget.item.macAddress != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('View device'),
              onPressed: () async {
                if (widget.item.isNew) await widget.onSetRead(true);
                if (context.mounted) {
                  context.push('/devices/${widget.item.macAddress}');
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: widget.item.isNew ? theme.colorScheme.secondaryContainer : null,
      child: Dismissible(
        key: ValueKey(widget.item.id),
        confirmDismiss: (direction) =>
            widget.onSetRead(direction != DismissDirection.startToEnd),
        background: Container(
          color: theme.colorScheme.tertiaryContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: Insets.lg),
          child: const Icon(Icons.mark_email_unread),
        ),
        secondaryBackground: Container(
          color: theme.colorScheme.primaryContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Insets.lg),
          child: const Icon(Icons.done),
        ),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(
                  widget.item.notificationType.icon,
                  color: widget.item.isNew ? theme.colorScheme.primary : null,
                ),
                title: Text(
                  '${widget.formatter.format(widget.item.createdOn)} - ${widget.item.title}',
                  style: widget.item.isNew
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                subtitle: Text(
                  widget.item.body,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _expanded
                    ? _buildActions(context)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
