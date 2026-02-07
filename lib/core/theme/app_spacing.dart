/// Design tokens for consistent spacing throughout the app.
///
/// Based on a 4px base unit with a geometric scale.
class AppSpacing {
  AppSpacing._();

  /// 4px - Extra small spacing
  static const double xs = 4;

  /// 8px - Small spacing
  static const double sm = 8;

  /// 12px - Medium-small spacing
  static const double md = 12;

  /// 16px - Large spacing (default)
  static const double lg = 16;

  /// 24px - Extra large spacing
  static const double xl = 24;

  /// 32px - 2x Extra large spacing
  static const double xxl = 32;

  /// 48px - 3x Extra large spacing
  static const double xxxl = 48;

  // Semantic spacing aliases
  /// Padding inside cards and containers
  static const double cardPadding = 20;

  /// Margin around cards
  static const double cardMargin = lg;

  /// Space between list items
  static const double listItemSpacing = md;

  /// Space between form fields
  static const double formFieldSpacing = xl;

  /// Space between sections
  static const double sectionSpacing = xxl;

  /// Screen edge padding
  static const double screenPadding = lg;
}
