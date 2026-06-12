import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Hosts snackbars *above* everything on screen, including dialog barriers.
///
/// A normal `ScaffoldMessenger.of(context)` snackbar is painted by the page
/// `Scaffold`, which sits below a dialog's modal barrier — so it gets dimmed by
/// the scrim while a dialog is open. This key belongs to a `ScaffoldMessenger`
/// wrapping a top-level `Scaffold` that is mounted *above* the router's
/// Navigator (see `main.dart`), so snackbars shown through it render on top of
/// every route. When the key is not mounted (e.g. in widget tests that pump a
/// bare `MaterialApp`) we fall back to the nearest messenger.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// `MaterialApp.builder` that mounts the app ([child], i.e. the router's
/// Navigator) beneath a top-level `ScaffoldMessenger` + `Scaffold`. Snackbars
/// shown through [rootMessengerKey] are rendered by that host Scaffold, which
/// sits above every route, so they paint on top of dialog barriers instead of
/// being dimmed by the scrim.
///
/// The host is wrapped in an [_OverlayHost] so the Scaffold has an `Overlay`
/// ancestor — the snackbar's close-icon tooltip and floating layout require one,
/// and the host Scaffold would otherwise have none (the Navigator's own Overlay
/// is a descendant). [_OverlayHost] rebuilds its entry as [child] changes, so
/// the live app is never frozen.
Widget buildSnackbarHost(BuildContext context, Widget? child) {
  return _OverlayHost(
    child: ScaffoldMessenger(
      key: rootMessengerKey,
      child: Scaffold(
        // Purely a snackbar host; the inner shell Scaffold owns layout and
        // keyboard-inset handling, so this one must not also resize.
        resizeToAvoidBottomInset: false,
        body: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

/// Provides an [Overlay] ancestor for [child] while keeping it live: a plain
/// `Overlay(initialEntries: ...)` captures its entry once and would freeze the
/// subtree, so we rebuild the single entry whenever [child] updates.
class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});

  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_OverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pull the latest [child] into the (otherwise static) overlay entry.
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

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

    final messenger =
        rootMessengerKey.currentState ?? ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: foreground)),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: foreground,
        backgroundColor: background,
      ),
    );
  }
}
