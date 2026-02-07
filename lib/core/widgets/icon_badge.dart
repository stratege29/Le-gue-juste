import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A reusable icon badge container with consistent styling.
///
/// Ensures minimum touch target of 48x48px for accessibility.
class IconBadge extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// Background color (will be applied with 0.1 opacity)
  final Color color;

  /// Size of the badge container (minimum 48x48 for accessibility)
  final double size;

  /// Icon size (defaults to 24)
  final double iconSize;

  /// Border radius (defaults to 12)
  final double borderRadius;

  /// Optional semantic label for accessibility
  final String? semanticLabel;

  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 48,
    this.iconSize = 24,
    this.borderRadius = 12,
    this.semanticLabel,
  }) : assert(size >= 48, 'Size must be at least 48px for accessibility');

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        icon,
        color: color,
        size: iconSize,
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        child: badge,
      );
    }

    return badge;
  }

  /// Factory for category icons in expense cards
  factory IconBadge.category(String? category) {
    return IconBadge(
      icon: _getCategoryIcon(category),
      color: AppColors.primary,
      semanticLabel: category ?? 'autre',
    );
  }

  /// Factory for balance indicator (positive/negative)
  factory IconBadge.balance({required bool isPositive}) {
    return IconBadge(
      icon: isPositive ? Icons.arrow_downward : Icons.arrow_upward,
      color: isPositive ? AppColors.success : AppColors.error,
      semanticLabel: isPositive ? 'Vous etes crediteur' : 'Vous etes debiteur',
    );
  }

  static IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
        return Icons.flash_on;
      case 'rent':
        return Icons.home;
      case 'travel':
        return Icons.flight;
      case 'health':
        return Icons.local_hospital;
      default:
        return Icons.receipt;
    }
  }
}
