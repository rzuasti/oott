import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UISnackbars {
  static void showError(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    _show(context, message, colorScheme.error, colorScheme.onError);
  }

  static void showSuccess(BuildContext context, String message) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    _show(context, message, appColors.success, appColors.onSuccess);
  }

  static void showWarning(BuildContext context, String message) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    _show(context, message, appColors.warning, appColors.onWarning);
  }

  static void showInfo(BuildContext context, String message) {
    final appColors = Theme.of(context).extension<AppColorExtension>()!;
    _show(context, message, appColors.info, appColors.onInfo);
  }

  static void _show(
    BuildContext context,
    String message,
    Color background,
    Color foreground,
  ) {
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
