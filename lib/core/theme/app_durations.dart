/// Design tokens for consistent animation durations throughout the app.
class AppDurations {
  AppDurations._();

  /// 150ms - Quick micro-interactions (button press, toggle)
  static const Duration fast = Duration(milliseconds: 150);

  /// 200ms - Standard interactions (chip selection)
  static const Duration normal = Duration(milliseconds: 200);

  /// 300ms - Page transitions, modal animations
  static const Duration slow = Duration(milliseconds: 300);

  /// 400ms - Complex animations, staggered lists
  static const Duration slower = Duration(milliseconds: 400);

  /// 500ms - Emphasis animations
  static const Duration slowest = Duration(milliseconds: 500);

  // Semantic aliases
  /// Duration for page/screen transitions
  static const Duration pageTransition = slow;

  /// Duration for modal/bottom sheet animations
  static const Duration modalTransition = slow;

  /// Duration for button feedback
  static const Duration buttonFeedback = fast;

  /// Duration for selection changes
  static const Duration selectionChange = normal;

  /// Duration for loading shimmer cycle
  static const Duration shimmerCycle = Duration(milliseconds: 1500);
}
