import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum BadgeColor { primary, secondary, tertiary, error, success }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeColor color;

  const StatusBadge({super.key, required this.label, required this.color});

  (Color, Color) _resolveColors(ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (color) {
      case BadgeColor.primary:
        return (scheme.primary, scheme.onPrimary);
      case BadgeColor.secondary:
        return (scheme.secondary, scheme.onSecondary);
      case BadgeColor.tertiary:
        return (scheme.tertiary, scheme.onTertiary);
      case BadgeColor.error:
        return (scheme.error, scheme.onError);
      case BadgeColor.success:
        final ext = theme.extension<AppColorExtension>()!;
        return (ext.success, ext.onSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = _resolveColors(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: bg,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
