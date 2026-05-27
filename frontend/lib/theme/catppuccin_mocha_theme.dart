import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class CatppuccinMochaColors {
  static const Color crust     = Color(0xFF11111b);
  static const Color mantle    = Color(0xFF181825);
  static const Color base      = Color(0xFF1e1e2e);
  static const Color surface0  = Color(0xFF313244);
  static const Color surface1  = Color(0xFF45475a);
  static const Color surface2  = Color(0xFF585b70);
  static const Color overlay0  = Color(0xFF6c7086);
  static const Color overlay1  = Color(0xFF7f849c);
  static const Color overlay2  = Color(0xFF9399b2);
  static const Color subtext0  = Color(0xFFa6adc8);
  static const Color subtext1  = Color(0xFFbac2de);
  static const Color text      = Color(0xFFcdd6f4);

  static const Color rosewater = Color(0xFFf5e0dc);
  static const Color flamingo  = Color(0xFFf2cdcd);
  static const Color pink      = Color(0xFFf5c2e7);
  static const Color mauve     = Color(0xFFcba6f7);
  static const Color red       = Color(0xFFf38ba8);
  static const Color maroon    = Color(0xFFeba0ac);
  static const Color peach     = Color(0xFFfab387);
  static const Color yellow    = Color(0xFFf9e2af);
  static const Color green     = Color(0xFFa6e3a1);
  static const Color teal      = Color(0xFF94e2d5);
  static const Color sky       = Color(0xFF89dceb);
  static const Color sapphire  = Color(0xFF74c7ec);
  static const Color blue      = Color(0xFF89b4fa);
  static const Color lavender  = Color(0xFFb4befe);
}

const ColorScheme _catppuccinMochaColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // Surfaces — AppBar (darkest) → NavRail → body (lightest)
  surface:                 CatppuccinMochaColors.base,
  surfaceContainerLowest:  CatppuccinMochaColors.crust,
  surfaceContainerLow:     CatppuccinMochaColors.mantle,
  surfaceContainer:        CatppuccinMochaColors.surface0,
  surfaceContainerHigh:    CatppuccinMochaColors.surface1,
  surfaceContainerHighest: CatppuccinMochaColors.surface2,
  onSurface:               CatppuccinMochaColors.text,
  onSurfaceVariant:        CatppuccinMochaColors.subtext1,
  outline:                 CatppuccinMochaColors.overlay1,
  outlineVariant:          CatppuccinMochaColors.overlay0,

  // Primary — Save button, selected nav indicators
  primary:            CatppuccinMochaColors.mauve,
  onPrimary:          CatppuccinMochaColors.crust,
  primaryContainer:   CatppuccinMochaColors.surface0,
  onPrimaryContainer: CatppuccinMochaColors.text,

  // Secondary — Test button (not-passing state)
  secondary:            CatppuccinMochaColors.blue,
  onSecondary:          CatppuccinMochaColors.crust,
  secondaryContainer:   CatppuccinMochaColors.surface1,
  onSecondaryContainer: CatppuccinMochaColors.text,

  // Tertiary — swipe-to-unread background
  tertiary:            CatppuccinMochaColors.teal,
  onTertiary:          CatppuccinMochaColors.crust,
  tertiaryContainer:   CatppuccinMochaColors.surface0,
  onTertiaryContainer: CatppuccinMochaColors.text,

  // Error
  error:            CatppuccinMochaColors.red,
  onError:          CatppuccinMochaColors.crust,
  errorContainer:   CatppuccinMochaColors.maroon,
  onErrorContainer: CatppuccinMochaColors.crust,

  // Inverse / scrim
  inverseSurface:   CatppuccinMochaColors.text,
  onInverseSurface: CatppuccinMochaColors.crust,
  inversePrimary:   CatppuccinMochaColors.mauve,
  scrim:            CatppuccinMochaColors.crust,
  shadow:           CatppuccinMochaColors.crust,
);

final ThemeData catppuccinMochaDarkTheme = ThemeData(
  colorScheme: _catppuccinMochaColorScheme,
  extensions: [
    const AppColorExtension(
      success: CatppuccinMochaColors.green,
      onSuccess: CatppuccinMochaColors.crust,
    ),
  ],
);
