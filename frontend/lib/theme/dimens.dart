/// Shared layout tokens for consistent spacing and responsive breakpoints.
///
/// Use these instead of hand-written magic numbers so spacing stays uniform
/// across screens and breakpoints are defined in a single place.
library;

/// Spacing scale (logical pixels). Used for padding, margins and gaps.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Responsive layout breakpoints, aligned with Material 3 window size classes.
abstract final class Breakpoints {
  /// Compact → medium: switch from bottom NavigationBar to NavigationRail.
  static const double medium = 600;

  /// Medium → expanded: extend the NavigationRail with labels.
  static const double expanded = 840;

  /// Home screen switches to its two-column layout at this width.
  static const double twoColumn = 700;
}
