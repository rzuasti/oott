import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds a Material 3 [ThemeData] from a [ColorScheme] and the app's custom
/// [AppColorExtension], applying the shared OOTT typography.
///
/// Both bundled themes (Catppuccin Mocha, Gruvbox Dark) go through here so they
/// stay visually consistent — only their colors differ.
ThemeData buildAppTheme({
  required ColorScheme colorScheme,
  required AppColorExtension appColors,
}) {
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
  return base.copyWith(
    textTheme: _brandTextTheme(base.textTheme),
    extensions: [appColors],
  );
}

/// Applies the OOTT brand font (Barlow Condensed) to display, headline and
/// large-title styles while leaving body/label styles on the default face for
/// readability. Sizes and colors from [base] are preserved.
TextTheme _brandTextTheme(TextTheme base) {
  final branded = GoogleFonts.barlowCondensedTextTheme(base);
  return base.copyWith(
    displayLarge: branded.displayLarge,
    displayMedium: branded.displayMedium,
    displaySmall: branded.displaySmall,
    headlineLarge: branded.headlineLarge,
    headlineMedium: branded.headlineMedium,
    headlineSmall: branded.headlineSmall,
    titleLarge: branded.titleLarge,
  );
}
