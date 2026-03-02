import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Semantics(
            label: 'Options des notifications',
            button: true,
            child: PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (value) {
                HapticFeedback.lightImpact();
                if (value == 'mark_all_read') {
                  ref.read(notificationsNotifierProvider.notifier).markAllAsRead();
                } else if (value == 'clear_all') {
                  _showClearAllDialog(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all),
                      SizedBox(width: 8),
                      Text('Tout marquer comme lu'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Tout supprimer', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_none,
              title: 'Aucune notification',
              description: 'Vous recevrez des notifications pour les nouvelles dépenses et remboursements',
            );
          }
          return _buildNotificationsList(context, ref, notifications);
        },
        loading: () => const SkeletonScreen(showSummaryCard: false),
        error: (_, __) => const EmptyStateWidget(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Erreur',
          description: 'Impossible de charger vos notifications',
        ),
      ),
    );
  }

  Widget _buildNotificationsList(
      BuildContext context, WidgetRef ref, List<NotificationEntity> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(context, ref, notification);
      },
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, WidgetRef ref, NotificationEntity notification) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.type);
    final isFriendRequest = notification.type == FirebaseConstants.friendRequestType;

    return Semantics(
      label: '${notification.title}. ${notification.body}. ${notification.isRead ? "Lu" : "Non lu"}',
      button: true,
      child: Dismissible(
        key: Key(notification.id),
        direction: isFriendRequest ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          ref.read(notificationsNotifierProvider.notifier).deleteNotification(notification.id);
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: notification.isRead ? null : AppColors.primary.withValues(alpha: 0.05),
          child: InkWell(
            onTap: isFriendRequest
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    if (!notification.isRead) {
                      ref.read(notificationsNotifierProvider.notifier).markAsRead(notification.id);
                    }
                    if (notification.groupId != null) {
                      context.push('/groups/${notification.groupId}');
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    icon: icon,
                    color: color,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: AppColors.gray600,
                          fontSize: 13,
                        ),
                      ),
                      if (isFriendRequest && notification.requestId != null) ...[
                        const SizedBox(height: 12),
                        _FriendRequestActions(notification: notification),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(
                          color: AppColors.gray400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'expense_added':
        return Icons.receipt_long;
      case 'group_invite':
        return Icons.group_add;
      case 'payment_received':
        return Icons.payments;
      case 'payment_reminder':
        return Icons.notification_important;
      case FirebaseConstants.friendRequestType:
        return Icons.person_add;
      case FirebaseConstants.friendRequestAcceptedType:
        return Icons.how_to_reg;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'expense_added':
        return AppColors.primary;
      case 'group_invite':
        return AppColors.secondary;
      case 'payment_received':
        return AppColors.success;
      case 'payment_reminder':
        return AppColors.warning;
      case FirebaseConstants.friendRequestType:
        return Colors.green;
      case FirebaseConstants.friendRequestAcceptedType:
        return AppColors.primary;
      default:
        return AppColors.gray600;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return "À l'instant";
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer toutes les notifications?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(notificationsNotifierProvider.notifier).clearAllNotifications();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _FriendRequestActions extends ConsumerStatefulWidget {
  final NotificationEntity notification;

  const _FriendRequestActions({required this.notification});

  @override
  ConsumerState<_FriendRequestActions> createState() => _FriendRequestActionsState();
}

class _FriendRequestActionsState extends ConsumerState<_FriendRequestActions> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      children: [
        FilledButton.tonal(
          onPressed: () => _accept(context),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            foregroundColor: Colors.green,
          ),
          child: const Text('Accepter'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => _decline(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Refuser'),
        ),
      ],
    );
  }

  Future<void> _accept(BuildContext context) async {
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final notification = widget.notification;

    // Build a FriendRequestEntity from notification data
    final request = FriendRequestEntity(
      id: notification.requestId!,
      fromUserId: notification.fromUserId ?? '',
      fromDisplayName: '', // will be looked up in provider
      fromPhoneNumber: '',
      status: 'pending',
      createdAt: notification.createdAt,
    );

    final success = await ref.read(friendsNotifierProvider.notifier).acceptFriendRequest(request);

    if (!mounted) return;

    if (success) {
      SnackbarManager.showSuccess(context, 'Demande acceptée !');
    } else {
      setState(() => _processing = false);
      SnackbarManager.showError(context, 'Erreur lors de l\'acceptation');
    }
  }

  Future<void> _decline(BuildContext context) async {
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final success = await ref.read(friendsNotifierProvider.notifier).declineFriendRequest(widget.notification.requestId!);

    if (!mounted) return;

    if (success) {
      SnackbarManager.showSuccess(context, 'Demande refusée');
    } else {
      setState(() => _processing = false);
      SnackbarManager.showError(context, 'Erreur');
    }
  }
}
