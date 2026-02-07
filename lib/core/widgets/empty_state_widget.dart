import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A reusable widget for displaying empty states across the app.
///
/// Follows accessibility guidelines with proper Semantics and minimum
/// touch targets of 48x48px for action buttons.
class EmptyStateWidget extends StatelessWidget {
  /// The icon to display (defaults to a generic empty icon)
  final IconData icon;

  /// Primary title text
  final String title;

  /// Secondary description text
  final String? description;

  /// Optional action button text
  final String? actionLabel;

  /// Callback when action button is pressed
  final VoidCallback? onAction;

  /// Icon color (defaults to AppColors.gray400)
  final Color? iconColor;

  /// Icon size (defaults to 80)
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. ${description ?? ""}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppColors.gray400,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.gray600,
                    ),
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 48, // Minimum touch target
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onAction!();
                    },
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A specialized empty state for "all settled" scenarios
class AllSettledStateWidget extends StatelessWidget {
  final String? subtitle;

  const AllSettledStateWidget({
    super.key,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.check_circle_outline,
      iconColor: AppColors.success,
      title: 'Tout est equilibre!',
      description: subtitle ?? 'Aucune dette en cours',
    );
  }
}
