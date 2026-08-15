import 'dart:math' as math;

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

    switch (style) {
      case LoadingButtonStyle.elevated:
        return _animatedWidth(
          ElevatedButton(
            onPressed: isDisabled ? null : handlePress,
            child: child,
          ),
        );
      case LoadingButtonStyle.outlined:
        return _animatedWidth(
          OutlinedButton(
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

  /// Wraps [button] in a width animation that shrinks it to a pill while
  /// loading.
  ///
  /// The animation always runs between two *finite* widths: interpolating
  /// towards `double.infinity` makes [AnimatedContainer] assert with
  /// "Cannot interpolate between finite constraints and unbounded
  /// constraints". When the incoming constraints are unbounded there is no
  /// finite target width, so the button simply sizes itself to its content.
  Widget _animatedWidth(Widget button) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          if (!maxWidth.isFinite) {
            return SizedBox(height: minHeight, child: button);
          }
          final collapsedWidth = math.min(minHeight * 2, maxWidth);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isLoading ? collapsedWidth : maxWidth,
            height: minHeight,
            child: button,
          );
        },
      ),
    );
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
