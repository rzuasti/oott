import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

abstract final class NordColors {
  // Polar Night (nord0–nord3). nord0Dark is interpolated below nord0 to give
  // the AppBar a slightly deeper shade than the body.
  static const Color nord0Dark = Color(0xFF2b303b);
  static const Color nord0 = Color(0xFF2e3440);
  static const Color nord0Soft = Color(0xFF353c4a);
  static const Color nord1 = Color(0xFF3b4252);
  static const Color nord2 = Color(0xFF434c5e);
  static const Color nord3 = Color(0xFF4c566a);

  // Snow Storm (nord4–nord6)
  static const Color nord4 = Color(0xFFd8dee9);
  static const Color nord5 = Color(0xFFe5e9f0);
  static const Color nord6 = Color(0xFFeceff4);

  // Frost (nord7–nord10)
  static const Color nord7 = Color(0xFF8fbcbb);
  static const Color nord8 = Color(0xFF88c0d0);
  static const Color nord9 = Color(0xFF81a1c1);
  static const Color nord10 = Color(0xFF5e81ac);

  // Aurora (nord11–nord15)
  static const Color nord11 = Color(0xFFbf616a);
  static const Color nord12 = Color(0xFFd08770);
  static const Color nord13 = Color(0xFFebcb8b);
  static const Color nord14 = Color(0xFFa3be8c);
  static const Color nord15 = Color(0xFFb48ead);
}

const ColorScheme _nordColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: NordColors.nord0,
  surfaceContainerLowest: NordColors.nord0Dark,
  surfaceContainerLow: NordColors.nord0Soft,
  surfaceContainer: NordColors.nord1,
  surfaceContainerHigh: NordColors.nord2,
  surfaceContainerHighest: NordColors.nord3,
  onSurface: NordColors.nord6,
  onSurfaceVariant: NordColors.nord4,
  outline: NordColors.nord3,
  outlineVariant: NordColors.nord2,

  // Primary — Save button, selected nav indicators
  primary: NordColors.nord8,
  onPrimary: NordColors.nord0,
  primaryContainer: NordColors.nord1,
  onPrimaryContainer: NordColors.nord6,

  // Secondary — Test button (not-passing state)
  secondary: NordColors.nord9,
  onSecondary: NordColors.nord0,
  secondaryContainer: NordColors.nord2,
  onSecondaryContainer: NordColors.nord6,

  // Tertiary — swipe-to-unread background
  tertiary: NordColors.nord7,
  onTertiary: NordColors.nord0,
  tertiaryContainer: NordColors.nord1,
  onTertiaryContainer: NordColors.nord6,

  // Error
  error: NordColors.nord11,
  onError: NordColors.nord6,
  errorContainer: NordColors.nord11,
  onErrorContainer: NordColors.nord0,

  // Inverse / scrim
  inverseSurface: NordColors.nord6,
  onInverseSurface: NordColors.nord0,
  inversePrimary: NordColors.nord10,
  scrim: NordColors.nord0Dark,
  shadow: NordColors.nord0Dark,
);

final ThemeData nordDarkTheme = buildAppTheme(
  colorScheme: _nordColorScheme,
  appColors: const AppColorExtension(
    success: NordColors.nord14,
    onSuccess: NordColors.nord0,
    warning: NordColors.nord13,
    onWarning: NordColors.nord0,
    info: NordColors.nord8,
    onInfo: NordColors.nord0,
  ),
);
