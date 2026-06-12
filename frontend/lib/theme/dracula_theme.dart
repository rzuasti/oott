import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

abstract final class DraculaColors {
  // Neutral ramp (darkest → lightest). "black" and "currentLine" come from the
  // official palette; the intermediate elevated surfaces are interpolated.
  static const Color blacker = Color(0xFF1b1c24);
  static const Color black = Color(0xFF21222c);
  static const Color background = Color(0xFF282a36);
  static const Color elevated = Color(0xFF343746);
  static const Color currentLine = Color(0xFF44475a);
  static const Color overlay = Color(0xFF565872);
  static const Color comment = Color(0xFF6272a4);
  static const Color subtleForeground = Color(0xFFb8bbd0);
  static const Color foreground = Color(0xFFf8f8f2);

  static const Color cyan = Color(0xFF8be9fd);
  static const Color green = Color(0xFF50fa7b);
  static const Color orange = Color(0xFFffb86c);
  static const Color pink = Color(0xFFff79c6);
  static const Color purple = Color(0xFFbd93f9);
  static const Color red = Color(0xFFff5555);
  static const Color brightRed = Color(0xFFff6e6e);
  static const Color yellow = Color(0xFFf1fa8c);
}

const ColorScheme _draculaColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: DraculaColors.background,
  surfaceContainerLowest: DraculaColors.blacker,
  surfaceContainerLow: DraculaColors.black,
  surfaceContainer: DraculaColors.elevated,
  surfaceContainerHigh: DraculaColors.currentLine,
  surfaceContainerHighest: DraculaColors.overlay,
  onSurface: DraculaColors.foreground,
  onSurfaceVariant: DraculaColors.subtleForeground,
  outline: DraculaColors.comment,
  outlineVariant: DraculaColors.currentLine,

  // Primary — Save button, selected nav indicators
  primary: DraculaColors.purple,
  onPrimary: DraculaColors.background,
  primaryContainer: DraculaColors.currentLine,
  onPrimaryContainer: DraculaColors.foreground,

  // Secondary — Test button (not-passing state)
  secondary: DraculaColors.cyan,
  onSecondary: DraculaColors.background,
  secondaryContainer: DraculaColors.elevated,
  onSecondaryContainer: DraculaColors.foreground,

  // Tertiary — swipe-to-unread background
  tertiary: DraculaColors.pink,
  onTertiary: DraculaColors.background,
  tertiaryContainer: DraculaColors.currentLine,
  onTertiaryContainer: DraculaColors.foreground,

  // Error
  error: DraculaColors.red,
  onError: DraculaColors.background,
  errorContainer: DraculaColors.brightRed,
  onErrorContainer: DraculaColors.background,

  // Inverse / scrim
  inverseSurface: DraculaColors.foreground,
  onInverseSurface: DraculaColors.background,
  inversePrimary: DraculaColors.purple,
  scrim: DraculaColors.black,
  shadow: DraculaColors.black,
);

final ThemeData draculaDarkTheme = buildAppTheme(
  colorScheme: _draculaColorScheme,
  appColors: const AppColorExtension(
    success: DraculaColors.green,
    onSuccess: DraculaColors.background,
    warning: DraculaColors.orange,
    onWarning: DraculaColors.background,
    info: DraculaColors.cyan,
    onInfo: DraculaColors.background,
  ),
);
