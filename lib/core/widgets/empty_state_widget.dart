import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A reusable widget for displaying empty states across the app.
///
/// Follows accessibility guidelines with proper Semantics and minimum
/// touch targets of 48x48px for action buttons.
class EmptyStateWidget extends StatefulWidget {
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
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.title}. ${widget.description ?? ""}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: widget.iconSize + 32,
                  height: widget.iconSize + 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (widget.iconColor ?? AppColors.gray400).withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize * 0.6,
                    color: widget.iconColor ?? AppColors.gray400,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.gray600,
                    ),
                textAlign: TextAlign.center,
              ),
              if (widget.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 48, // Minimum touch target
                  child: FilledButton.tonal(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onAction!();
                    },
                    child: Text(widget.actionLabel!),
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
