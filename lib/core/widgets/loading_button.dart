import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button that shows a loading indicator when an async operation is in progress.
///
/// Provides haptic feedback on press, smooth morphing animation between states,
/// and meets minimum touch target requirements.
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

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : icon != null
              ? Row(
                  key: const ValueKey('icon-label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                )
              : Text(key: const ValueKey('label'), label),
    );

    // Animated width: shrink to circle when loading
    final buttonChild = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(
        minWidth: isLoading ? minHeight : double.infinity,
        minHeight: minHeight,
      ),
      child: child,
    );

    switch (style) {
      case LoadingButtonStyle.elevated:
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isLoading ? minHeight * 2 : double.infinity,
            height: minHeight,
            child: ElevatedButton(
              onPressed: isDisabled ? null : handlePress,
              child: buttonChild,
            ),
          ),
        );
      case LoadingButtonStyle.outlined:
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isLoading ? minHeight * 2 : double.infinity,
            height: minHeight,
            child: OutlinedButton(
              onPressed: isDisabled ? null : handlePress,
              child: buttonChild,
            ),
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
