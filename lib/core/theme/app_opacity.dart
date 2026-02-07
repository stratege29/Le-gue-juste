/// Design tokens for consistent opacity values throughout the app.
///
/// Use these instead of arbitrary opacity values to maintain visual consistency.
class AppOpacity {
  AppOpacity._();

  /// 0.05 - Very subtle background tints
  static const double subtle = 0.05;

  /// 0.1 - Light background for icon badges, chips
  static const double light = 0.1;

  /// 0.2 - Medium-light for selected states
  static const double mediumLight = 0.2;

  /// 0.3 - Medium for dividers, separators
  static const double medium = 0.3;

  /// 0.5 - Half opacity for disabled states
  static const double half = 0.5;

  /// 0.6 - Medium-strong for secondary text on dark backgrounds
  static const double mediumStrong = 0.6;

  /// 0.8 - Strong opacity for primary text on colored backgrounds
  static const double strong = 0.8;

  /// 1.0 - Full opacity (default)
  static const double full = 1.0;
}
