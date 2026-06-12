import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

/// Alucard — the official light counterpart to Dracula.
abstract final class AlucardColors {
  // Neutral ramp (lightest → darkest). Background, the warm/cream tints and the
  // darker gray are from the base24 Alucard palette; the two mid surfaces are
  // interpolated to give cards consistent elevation steps.
  static const Color background = Color(0xFFfffbeb);
  static const Color warm = Color(0xFFfdf8e2);
  static const Color cream = Color(0xFFf5f0da);
  static const Color surface = Color(0xFFf0ebd5);
  static const Color surfaceHigh = Color(0xFFded8c2);
  static const Color gray = Color(0xFFceccc0);
  static const Color comment = Color(0xFF6c664b);
  static const Color subtleForeground = Color(0xFF4c4a3d);
  static const Color foreground = Color(0xFF1f1f1f);

  static const Color cyan = Color(0xFF036a96);
  static const Color green = Color(0xFF14710a);
  static const Color orange = Color(0xFFa34d14);
  static const Color pink = Color(0xFFa3144d);
  static const Color purple = Color(0xFF644ac9);
  static const Color brightPurple = Color(0xFF7862d0);
  static const Color red = Color(0xFFcb3a2a);
  static const Color darkRed = Color(0xFF792219);
  static const Color redContainer = Color(0xFFf5d6d1);
  static const Color yellow = Color(0xFF846e15);
}

const ColorScheme _alucardColorScheme = ColorScheme(
  brightness: Brightness.light,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: AlucardColors.background,
  surfaceContainerLowest: AlucardColors.cream,
  surfaceContainerLow: AlucardColors.warm,
  surfaceContainer: AlucardColors.surface,
  surfaceContainerHigh: AlucardColors.surfaceHigh,
  surfaceContainerHighest: AlucardColors.gray,
  onSurface: AlucardColors.foreground,
  onSurfaceVariant: AlucardColors.subtleForeground,
  outline: AlucardColors.comment,
  outlineVariant: AlucardColors.gray,

  // Primary — Save button, selected nav indicators
  primary: AlucardColors.purple,
  onPrimary: AlucardColors.background,
  primaryContainer: AlucardColors.surfaceHigh,
  onPrimaryContainer: AlucardColors.foreground,

  // Secondary — Test button (not-passing state)
  secondary: AlucardColors.cyan,
  onSecondary: AlucardColors.background,
  secondaryContainer: AlucardColors.gray,
  onSecondaryContainer: AlucardColors.foreground,

  // Tertiary — swipe-to-unread background
  tertiary: AlucardColors.green,
  onTertiary: AlucardColors.background,
  tertiaryContainer: AlucardColors.surface,
  onTertiaryContainer: AlucardColors.foreground,

  // Error
  error: AlucardColors.red,
  onError: AlucardColors.background,
  errorContainer: AlucardColors.redContainer,
  onErrorContainer: AlucardColors.darkRed,

  // Inverse / scrim
  inverseSurface: AlucardColors.foreground,
  onInverseSurface: AlucardColors.background,
  inversePrimary: AlucardColors.brightPurple,
  scrim: AlucardColors.foreground,
  shadow: AlucardColors.comment,
);

final ThemeData alucardLightTheme = buildAppTheme(
  colorScheme: _alucardColorScheme,
  appColors: const AppColorExtension(
    success: AlucardColors.green,
    onSuccess: AlucardColors.background,
    warning: AlucardColors.orange,
    onWarning: AlucardColors.background,
    info: AlucardColors.cyan,
    onInfo: AlucardColors.background,
  ),
);
