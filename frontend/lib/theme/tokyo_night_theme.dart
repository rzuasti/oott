import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

/// Tokyo Night (the "Night" variant).
abstract final class TokyoNightColors {
  static const Color bgDarker = Color(0xFF0c0e14);
  static const Color bgDark = Color(0xFF16161e);
  static const Color bg = Color(0xFF1a1b26);
  static const Color bgSoft = Color(0xFF1b1e2d);
  static const Color bgElevated = Color(0xFF24283b);
  static const Color bgHighlight = Color(0xFF292e42);
  static const Color fgGutter = Color(0xFF3b4261);
  static const Color terminalBlack = Color(0xFF414868);
  static const Color comment = Color(0xFF565f89);
  static const Color fgDark = Color(0xFFa9b1d6);
  static const Color fg = Color(0xFFc0caf5);

  static const Color blue = Color(0xFF7aa2f7);
  static const Color cyan = Color(0xFF7dcfff);
  static const Color teal = Color(0xFF73daca);
  static const Color green = Color(0xFF9ece6a);
  static const Color magenta = Color(0xFFbb9af7);
  static const Color purple = Color(0xFF9d7cd8);
  static const Color orange = Color(0xFFff9e64);
  static const Color yellow = Color(0xFFe0af68);
  static const Color red = Color(0xFFf7768e);
  static const Color brightRed = Color(0xFFdb4b4b);
}

const ColorScheme _tokyoNightColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: TokyoNightColors.bg,
  surfaceContainerLowest: TokyoNightColors.bgDark,
  surfaceContainerLow: TokyoNightColors.bgSoft,
  surfaceContainer: TokyoNightColors.bgElevated,
  surfaceContainerHigh: TokyoNightColors.bgHighlight,
  surfaceContainerHighest: TokyoNightColors.fgGutter,
  onSurface: TokyoNightColors.fg,
  onSurfaceVariant: TokyoNightColors.fgDark,
  outline: TokyoNightColors.comment,
  outlineVariant: TokyoNightColors.terminalBlack,

  // Primary — Save button, selected nav indicators
  primary: TokyoNightColors.blue,
  onPrimary: TokyoNightColors.bgDark,
  primaryContainer: TokyoNightColors.bgHighlight,
  onPrimaryContainer: TokyoNightColors.fg,

  // Secondary — Test button (not-passing state)
  secondary: TokyoNightColors.magenta,
  onSecondary: TokyoNightColors.bgDark,
  secondaryContainer: TokyoNightColors.fgGutter,
  onSecondaryContainer: TokyoNightColors.fg,

  // Tertiary — swipe-to-unread background
  tertiary: TokyoNightColors.teal,
  onTertiary: TokyoNightColors.bgDark,
  tertiaryContainer: TokyoNightColors.bgElevated,
  onTertiaryContainer: TokyoNightColors.fg,

  // Error
  error: TokyoNightColors.red,
  onError: TokyoNightColors.bgDark,
  errorContainer: TokyoNightColors.brightRed,
  onErrorContainer: TokyoNightColors.fg,

  // Inverse / scrim
  inverseSurface: TokyoNightColors.fg,
  onInverseSurface: TokyoNightColors.bgDark,
  inversePrimary: TokyoNightColors.blue,
  scrim: TokyoNightColors.bgDarker,
  shadow: TokyoNightColors.bgDarker,
);

final ThemeData tokyoNightDarkTheme = buildAppTheme(
  colorScheme: _tokyoNightColorScheme,
  appColors: const AppColorExtension(
    success: TokyoNightColors.green,
    onSuccess: TokyoNightColors.bgDark,
    warning: TokyoNightColors.yellow,
    onWarning: TokyoNightColors.bgDark,
    info: TokyoNightColors.blue,
    onInfo: TokyoNightColors.bgDark,
  ),
);
