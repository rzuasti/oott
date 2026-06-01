import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum _Severity { error, success, warning, info }

class UISnackbars {
  static void showError(BuildContext context, String message) =>
      _show(context, message, _Severity.error);

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, _Severity.success);

  static void showWarning(BuildContext context, String message) =>
      _show(context, message, _Severity.warning);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, _Severity.info);

  static void _show(BuildContext context, String message, _Severity severity) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final (background, foreground) = switch (severity) {
      _Severity.error => (theme.colorScheme.error, theme.colorScheme.onError),
      _Severity.success => (colors.success, colors.onSuccess),
      _Severity.warning => (colors.warning, colors.onWarning),
      _Severity.info => (colors.info, colors.onInfo),
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: foreground)),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: background,
      ),
    );
  }
}
