import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

abstract final class GruvboxColors {
  static const Color bgHard = Color(0xFF1d2021);
  static const Color bg = Color(0xFF282828);
  static const Color bgSoft = Color(0xFF32302f);
  static const Color bg1 = Color(0xFF3c3836);
  static const Color bg2 = Color(0xFF504945);
  static const Color bg3 = Color(0xFF665c54);
  static const Color bg4 = Color(0xFF7c6f64);
  static const Color fg = Color(0xFFebdbb2);
  static const Color fg2 = Color(0xFFd5c4a1);
  static const Color gray = Color(0xFF928374);
  static const Color red = Color(0xFFcc241d);
  static const Color brightRed = Color(0xFFfb4934);
  static const Color green = Color(0xFF98971a);
  static const Color brightGreen = Color(0xFFb8bb26);
  static const Color yellow = Color(0xFFd79921);
  static const Color brightYellow = Color(0xFFfabd2f);
  static const Color blue = Color(0xFF458588);
  static const Color brightBlue = Color(0xFF83a598);
  static const Color purple = Color(0xFFb16286);
  static const Color brightPurple = Color(0xFFd3869b);
  static const Color aqua = Color(0xFF689d6a);
  static const Color brightAqua = Color(0xFF8ec07c);
  static const Color orange = Color(0xFFd65d0e);
  static const Color brightOrange = Color(0xFFfe8019);
}

const ColorScheme _gruvboxColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: GruvboxColors.bgSoft,
  surfaceContainerLowest: GruvboxColors.bgHard,
  surfaceContainerLow: GruvboxColors.bg,
  surfaceContainer: GruvboxColors.bg1,
  surfaceContainerHigh: GruvboxColors.bg1,
  surfaceContainerHighest: GruvboxColors.bg2,
  onSurface: GruvboxColors.fg,
  onSurfaceVariant: GruvboxColors.fg2,
  outline: GruvboxColors.gray,
  outlineVariant: GruvboxColors.bg4,

  // Primary — Save button, selected nav indicators
  primary: GruvboxColors.brightOrange,
  onPrimary: GruvboxColors.bgHard,
  primaryContainer: GruvboxColors.bg1,
  onPrimaryContainer: GruvboxColors.fg,

  // Secondary — Test button (not-passing state)
  secondary: GruvboxColors.blue,
  onSecondary: GruvboxColors.fg,
  secondaryContainer: GruvboxColors.bg2,
  onSecondaryContainer: GruvboxColors.fg,

  // Tertiary — swipe-to-unread background
  tertiary: GruvboxColors.aqua,
  onTertiary: GruvboxColors.bgHard,
  tertiaryContainer: GruvboxColors.bg1,
  onTertiaryContainer: GruvboxColors.fg,

  // Error
  error: GruvboxColors.brightRed,
  onError: GruvboxColors.bgHard,
  errorContainer: GruvboxColors.red,
  onErrorContainer: GruvboxColors.fg,

  // Inverse / scrim
  inverseSurface: GruvboxColors.fg,
  onInverseSurface: GruvboxColors.bgHard,
  inversePrimary: GruvboxColors.orange,
  scrim: GruvboxColors.bgHard,
  shadow: GruvboxColors.bgHard,
);

final ThemeData gruvboxDarkTheme = buildAppTheme(
  colorScheme: _gruvboxColorScheme,
  appColors: const AppColorExtension(
    success: GruvboxColors.brightGreen,
    onSuccess: GruvboxColors.bgHard,
    warning: GruvboxColors.brightYellow,
    onWarning: GruvboxColors.bgHard,
    info: GruvboxColors.brightBlue,
    onInfo: GruvboxColors.bgHard,
  ),
);
