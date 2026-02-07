import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button that shows a loading indicator when an async operation is in progress.
///
/// Provides haptic feedback on press and meets minimum touch target requirements.
class LoadingButton extends StatelessWidget {
  /// The button label
  final String label;

  /// Whether the button is in loading state
  final bool isLoading;

  /// Callback when button is pressed (null to disable)
  final VoidCallback? onPressed;

  /// Optional leading icon
  final IconData? icon;

  /// Button style variant
  final LoadingButtonStyle style;

  /// Minimum height for accessibility (defaults to 48)
  final double minHeight;

  const LoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.style = LoadingButtonStyle.elevated,
    this.minHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    void handlePress() {
      if (isDisabled) return;
      HapticFeedback.mediumImpact();
      onPressed!();
    }

    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    switch (style) {
      case LoadingButtonStyle.elevated:
        return SizedBox(
          height: minHeight,
          child: ElevatedButton(
            onPressed: isDisabled ? null : handlePress,
            child: child,
          ),
        );
      case LoadingButtonStyle.outlined:
        return SizedBox(
          height: minHeight,
          child: OutlinedButton(
            onPressed: isDisabled ? null : handlePress,
            child: child,
          ),
        );
      case LoadingButtonStyle.text:
        return SizedBox(
          height: minHeight,
          child: TextButton(
            onPressed: isDisabled ? null : handlePress,
            child: child,
          ),
        );
    }
  }
}

enum LoadingButtonStyle {
  elevated,
  outlined,
  text,
}

/// A specialized loading button for form save actions
class SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  const SaveButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.label = 'Sauver',
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onPressed?.call();
            },
            child: Text(label),
          );
  }
}
