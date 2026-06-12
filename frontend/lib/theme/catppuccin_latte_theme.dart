import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_builder.dart';

abstract final class CatppuccinLatteColors {
  static const Color crust = Color(0xFFdce0e8);
  static const Color mantle = Color(0xFFe6e9ef);
  static const Color base = Color(0xFFeff1f5);
  static const Color surface0 = Color(0xFFccd0da);
  static const Color surface1 = Color(0xFFbcc0cc);
  static const Color surface2 = Color(0xFFacb0be);
  static const Color overlay0 = Color(0xFF9ca0b0);
  static const Color overlay1 = Color(0xFF8c8fa1);
  static const Color overlay2 = Color(0xFF7c7f93);
  static const Color subtext0 = Color(0xFF6c6f85);
  static const Color subtext1 = Color(0xFF5c5f77);
  static const Color text = Color(0xFF4c4f69);

  static const Color rosewater = Color(0xFFdc8a78);
  static const Color flamingo = Color(0xFFdd7878);
  static const Color pink = Color(0xFFea76cb);
  static const Color mauve = Color(0xFF8839ef);
  static const Color red = Color(0xFFd20f39);
  static const Color maroon = Color(0xFFe64553);
  static const Color peach = Color(0xFFfe640b);
  static const Color yellow = Color(0xFFdf8e1d);
  static const Color green = Color(0xFF40a02b);
  static const Color teal = Color(0xFF179299);
  static const Color sky = Color(0xFF04a5e5);
  static const Color sapphire = Color(0xFF209fb5);
  static const Color blue = Color(0xFF1e66f5);
  static const Color lavender = Color(0xFF7287fd);
}

const ColorScheme _catppuccinLatteColorScheme = ColorScheme(
  brightness: Brightness.light,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface: CatppuccinLatteColors.base,
  surfaceContainerLowest: CatppuccinLatteColors.crust,
  surfaceContainerLow: CatppuccinLatteColors.mantle,
  surfaceContainer: CatppuccinLatteColors.surface0,
  surfaceContainerHigh: CatppuccinLatteColors.surface1,
  surfaceContainerHighest: CatppuccinLatteColors.surface2,
  onSurface: CatppuccinLatteColors.text,
  onSurfaceVariant: CatppuccinLatteColors.subtext1,
  outline: CatppuccinLatteColors.overlay1,
  outlineVariant: CatppuccinLatteColors.overlay0,

  // Primary — Save button, selected nav indicators
  primary: CatppuccinLatteColors.mauve,
  onPrimary: CatppuccinLatteColors.base,
  primaryContainer: CatppuccinLatteColors.surface0,
  onPrimaryContainer: CatppuccinLatteColors.text,

  // Secondary — Test button (not-passing state)
  secondary: CatppuccinLatteColors.blue,
  onSecondary: CatppuccinLatteColors.base,
  secondaryContainer: CatppuccinLatteColors.surface1,
  onSecondaryContainer: CatppuccinLatteColors.text,

  // Tertiary — swipe-to-unread background
  tertiary: CatppuccinLatteColors.teal,
  onTertiary: CatppuccinLatteColors.base,
  tertiaryContainer: CatppuccinLatteColors.surface0,
  onTertiaryContainer: CatppuccinLatteColors.text,

  // Error
  error: CatppuccinLatteColors.red,
  onError: CatppuccinLatteColors.base,
  errorContainer: CatppuccinLatteColors.maroon,
  onErrorContainer: CatppuccinLatteColors.base,

  // Inverse / scrim
  inverseSurface: CatppuccinLatteColors.text,
  onInverseSurface: CatppuccinLatteColors.base,
  inversePrimary: CatppuccinLatteColors.mauve,
  scrim: CatppuccinLatteColors.crust,
  shadow: CatppuccinLatteColors.text,
);

final ThemeData catppuccinLatteLightTheme = buildAppTheme(
  colorScheme: _catppuccinLatteColorScheme,
  appColors: const AppColorExtension(
    success: CatppuccinLatteColors.green,
    onSuccess: CatppuccinLatteColors.base,
    warning: CatppuccinLatteColors.peach,
    onWarning: CatppuccinLatteColors.base,
    info: CatppuccinLatteColors.blue,
    onInfo: CatppuccinLatteColors.base,
  ),
);
