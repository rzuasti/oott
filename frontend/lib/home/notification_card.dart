import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../model/notification.dart' as oott_model;
import '../theme/app_colors.dart';
import '../theme/dimens.dart';
import '../utils/friendly_date_formatter.dart';
import '../routes.dart';

// How long the arrival highlight takes to fade out.
const _flashDuration = Duration(milliseconds: 900);

class NotificationCard extends StatefulWidget {
  final oott_model.Notification item;
  final FriendlyDateFormatter formatter;
  final Future<bool> Function(bool read) onSetRead;

  /// When true, the card briefly tints itself to draw attention to a freshly
  /// arrived notification, then fades the tint out.
  final bool flash;

  /// Called once the arrival highlight has finished fading.
  final VoidCallback? onFlashComplete;

  /// Asks the owner to drop this item from its list once it has left the
  /// current filter. [animated] is true for button-driven removals (the owner
  /// plays its own exit animation) and false for swipes, where [Dismissible]
  /// has already animated the card away and the owner only needs to reconcile.
  final void Function({required bool animated})? onRemove;

  const NotificationCard({
    required this.item,
    required this.formatter,
    required this.onSetRead,
    this.flash = false,
    this.onFlashComplete,
    this.onRemove,
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
            onPressed: () async {
              final left = await widget.onSetRead(widget.item.isNew);
              if (left) widget.onRemove?.call(animated: true);
            },
            child: Text(widget.item.isNew ? 'Mark as read' : 'Mark as unread'),
          ),
          if (widget.item.macAddress != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('View device'),
              onPressed: () async {
                if (widget.item.isNew) {
                  final left = await widget.onSetRead(true);
                  if (left) widget.onRemove?.call(animated: true);
                }
                if (context.mounted) {
                  context.push(Routes.deviceDetail(widget.item.macAddress!));
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
      // Clip so the arrival highlight overlay respects the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildDismissible(context, theme),
          if (widget.flash) _buildFlashOverlay(theme),
        ],
      ),
    );
  }

  // A translucent tint over the card that fades to transparent once, signalling
  // a freshly arrived notification. Uses the theme's info accent, never a
  // hardcoded colour.
  Widget _buildFlashOverlay(ThemeData theme) {
    final tint = theme.extension<AppColorExtension>()!.info;
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: _flashDuration,
          onEnd: widget.onFlashComplete,
          builder: (context, t, _) =>
              ColoredBox(color: tint.withValues(alpha: 0.3 * t)),
        ),
      ),
    );
  }

  Widget _buildDismissible(BuildContext context, ThemeData theme) {
    return Dismissible(
      key: ValueKey(widget.item.id),
      // Toggle read state on the backend; only let the card slide away when the
      // toggle succeeds and the item should leave the current filter. Returning
      // false snaps the card back (e.g. the "All" filter keeps the item).
      confirmDismiss: (direction) =>
          widget.onSetRead(direction != DismissDirection.startToEnd),
      // The swipe-out animation is already done; the owner just reconciles.
      onDismissed: (_) => widget.onRemove?.call(animated: false),
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
    );
  }
}
