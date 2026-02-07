import 'package:flutter/material.dart';

/// Design tokens for consistent border radius throughout the app.
class AppRadius {
  AppRadius._();

  /// 8px - Small radius for chips, badges
  static const double sm = 8;

  /// 12px - Medium radius for buttons, inputs
  static const double md = 12;

  /// 16px - Large radius for cards
  static const double lg = 16;

  /// 20px - Extra large radius for summary cards, bottom sheets
  static const double xl = 20;

  /// Circular radius
  static const double circular = 999;

  // Pre-built BorderRadius objects for convenience
  static BorderRadius get smallAll => BorderRadius.circular(sm);
  static BorderRadius get mediumAll => BorderRadius.circular(md);
  static BorderRadius get largeAll => BorderRadius.circular(lg);
  static BorderRadius get extraLargeAll => BorderRadius.circular(xl);

  /// Top-only radius for bottom sheets
  static BorderRadius get topSheet => const BorderRadius.vertical(
        top: Radius.circular(xl),
      );
}
