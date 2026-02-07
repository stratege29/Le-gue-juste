import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that wraps a child and provides haptic feedback on tap.
///
/// Use this to add haptic feedback to any tappable widget.
class HapticWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HapticType type;

  const HapticWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.type = HapticType.light,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              _triggerHaptic();
              onTap!();
            }
          : null,
      child: child,
    );
  }

  void _triggerHaptic() {
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }
}

enum HapticType {
  /// Light haptic for selections and minor interactions
  light,

  /// Medium haptic for confirmations and validations
  medium,

  /// Heavy haptic for important actions
  heavy,

  /// Selection click for list selections
  selection,
}

/// Extension to easily add haptic feedback to callbacks
extension HapticCallback on VoidCallback {
  /// Wraps this callback with light haptic feedback
  VoidCallback withLightHaptic() {
    return () {
      HapticFeedback.lightImpact();
      this();
    };
  }

  /// Wraps this callback with medium haptic feedback
  VoidCallback withMediumHaptic() {
    return () {
      HapticFeedback.mediumImpact();
      this();
    };
  }

  /// Wraps this callback with selection haptic feedback
  VoidCallback withSelectionHaptic() {
    return () {
      HapticFeedback.selectionClick();
      this();
    };
  }
}

/// Extension to add haptic feedback to GestureDetector
extension HapticGesture on GestureDetector {
  /// Creates a copy with haptic feedback added to onTap
  GestureDetector withHaptic([HapticType type = HapticType.light]) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              switch (type) {
                case HapticType.light:
                  HapticFeedback.lightImpact();
                  break;
                case HapticType.medium:
                  HapticFeedback.mediumImpact();
                  break;
                case HapticType.heavy:
                  HapticFeedback.heavyImpact();
                  break;
                case HapticType.selection:
                  HapticFeedback.selectionClick();
                  break;
              }
              onTap!();
            }
          : null,
      child: child,
    );
  }
}
