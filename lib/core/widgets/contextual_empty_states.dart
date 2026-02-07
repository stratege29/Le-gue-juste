import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Contextual empty state for when there are no groups
class NoGroupsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateGroup;

  const NoGroupsEmptyState({super.key, this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return _ContextualEmptyState(
      icon: Icons.group_add_outlined,
      iconColor: AppColors.primary,
      title: 'Aucun groupe',
      description: 'Creez ou rejoignez un groupe pour commencer a partager vos depenses',
      actionLabel: 'Creer un groupe',
      onAction: onCreateGroup,
    );
  }
}

/// Contextual empty state for when there are no expenses in a group
class NoExpensesEmptyState extends StatelessWidget {
  final VoidCallback? onAddExpense;

  const NoExpensesEmptyState({super.key, this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    return _ContextualEmptyState(
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.secondary,
      title: 'Aucune depense',
      description: 'Ajoutez votre premiere depense pour commencer le partage',
      actionLabel: 'Ajouter une depense',
      onAction: onAddExpense,
    );
  }
}

/// Contextual empty state for when there are no friends
class NoFriendsEmptyState extends StatelessWidget {
  final VoidCallback? onScanQr;

  const NoFriendsEmptyState({super.key, this.onScanQr});

  @override
  Widget build(BuildContext context) {
    return _ContextualEmptyState(
      icon: Icons.people_outline,
      iconColor: AppColors.accent,
      title: 'Aucun ami',
      description: 'Scannez un QR code pour ajouter vos premiers amis',
      actionLabel: 'Scanner un QR',
      onAction: onScanQr,
    );
  }
}

/// Contextual empty state for when there are no notifications
class NoNotificationsEmptyState extends StatelessWidget {
  const NoNotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ContextualEmptyState(
      icon: Icons.notifications_none_outlined,
      iconColor: AppColors.info,
      title: 'Aucune notification',
      description: 'Vous recevrez des notifications quand quelqu\'un vous ajoutera a un groupe',
    );
  }
}

/// Contextual empty state for when all debts are settled
class AllSettledEmptyState extends StatelessWidget {
  const AllSettledEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ContextualEmptyState(
      icon: Icons.celebration_outlined,
      iconColor: AppColors.success,
      title: 'Tout est equilibre!',
      description: 'Felicitations, vous n\'avez aucune dette en cours',
      showConfetti: true,
    );
  }
}

/// Contextual empty state for errors
class ErrorEmptyState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorEmptyState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _ContextualEmptyState(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      title: 'Oups!',
      description: message ?? 'Une erreur est survenue. Veuillez reessayer.',
      actionLabel: 'Reessayer',
      onAction: onRetry,
    );
  }
}

/// Contextual empty state for no internet connection
class NoConnectionEmptyState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoConnectionEmptyState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _ContextualEmptyState(
      icon: Icons.wifi_off_outlined,
      iconColor: AppColors.warning,
      title: 'Pas de connexion',
      description: 'Verifiez votre connexion internet et reessayez',
      actionLabel: 'Reessayer',
      onAction: onRetry,
    );
  }
}

/// Base contextual empty state widget
class _ContextualEmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showConfetti;

  const _ContextualEmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.showConfetti = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $description',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon container
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 56,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.gray600,
                    ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onAction!();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(actionLabel!),
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
