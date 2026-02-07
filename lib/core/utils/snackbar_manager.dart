import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A manager for showing snackbars with automatic clearing to prevent stacking.
///
/// Usage:
/// ```dart
/// SnackbarManager.showSuccess(context, 'Operation reussie!');
/// SnackbarManager.showError(context, 'Une erreur est survenue');
/// ```
class SnackbarManager {
  SnackbarManager._();

  /// Shows a success snackbar (green)
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.success,
      icon: Icons.check_circle_outline,
    );
    HapticFeedback.mediumImpact();
  }

  /// Shows an error snackbar (red)
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline,
    );
    HapticFeedback.heavyImpact();
  }

  /// Shows a warning snackbar (orange)
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.warning,
      icon: Icons.warning_amber_outlined,
    );
    HapticFeedback.lightImpact();
  }

  /// Shows an info snackbar (blue)
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.info,
      icon: Icons.info_outline,
    );
  }

  /// Shows a snackbar with an action button
  static void showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Color? backgroundColor,
  }) {
    _show(
      context,
      message: message,
      backgroundColor: backgroundColor ?? AppColors.gray800,
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: () {
          HapticFeedback.lightImpact();
          onAction();
        },
      ),
    );
  }

  /// Shows a snackbar with undo action
  static void showWithUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
  }) {
    showWithAction(
      context,
      message: message,
      actionLabel: 'Annuler',
      onAction: onUndo,
    );
  }

  /// Internal method to show snackbar
  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Clear any existing snackbars first
    ScaffoldMessenger.of(context).clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      duration: duration,
      action: action,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Clears all snackbars
  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
