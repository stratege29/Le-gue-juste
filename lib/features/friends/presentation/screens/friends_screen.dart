import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(userFriendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Amis'),
        actions: [
          Semantics(
            label: 'Ajouter un ami',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Ajouter un ami',
              onPressed: () {
                HapticFeedback.lightImpact();
                _showAddFriendOptions(context, ref);
              },
            ),
          ),
        ],
      ),
      body: friendsAsync.when(
        data: (friends) {
          if (friends.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'Aucun ami',
              description: 'Scannez le QR code d\'un ami ou partagez le votre pour commencer',
              actionLabel: 'Ajouter un ami',
              onAction: () => _showAddFriendOptions(context, ref),
            );
          }
          return _buildFriendsList(context, ref, friends);
        },
        loading: () => const SkeletonScreen(showSummaryCard: false),
        error: (_, __) => const EmptyStateWidget(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Erreur',
          description: 'Impossible de charger vos amis',
        ),
      ),
      floatingActionButton: Semantics(
        label: 'Ajouter un ami',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            _showAddFriendOptions(context, ref);
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter'),
        ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, WidgetRef ref, List<FriendEntity> friends) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return Semantics(
          label: '${friend.displayName}, ami depuis ${_formatDate(friend.addedAt)}',
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                child: friend.avatarUrl == null
                    ? Text(
                        friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                friend.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Ami depuis ${_formatDate(friend.addedAt)}',
                style: TextStyle(color: AppColors.gray500, fontSize: 12),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  HapticFeedback.lightImpact();
                  if (value == 'remove') {
                    _showRemoveFriendDialog(context, ref, friend);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return "aujourd'hui";
    } else if (diff.inDays == 1) {
      return 'hier';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} jours';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} semaines';
    } else {
      return '${(diff.inDays / 30).floor()} mois';
    }
  }

  void _showAddFriendOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ajouter un ami',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
              ),
              title: const Text('Scanner un QR code'),
              subtitle: const Text('Scannez le code de votre ami'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RouteConstants.scanQr);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code, color: AppColors.secondary),
              ),
              title: const Text('Mon QR code'),
              subtitle: const Text('Montrez votre code a un ami'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RouteConstants.myQrCode);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.keyboard, color: AppColors.gray600),
              ),
              title: const Text('Entrer un code'),
              subtitle: const Text('Saisissez le code manuellement'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showEnterCodeDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEnterCodeDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrer un code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Code ami (ex: LGJ-XXXXXXXX-...)',
            hintText: 'LGJ-',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref.read(friendsNotifierProvider.notifier).addFriendByQrCode(code);
                if (context.mounted) {
                  if (success) {
                    SnackbarManager.showSuccess(context, 'Ami ajoute!');
                  } else {
                    SnackbarManager.showError(context, 'Erreur lors de l\'ajout');
                  }
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(BuildContext context, WidgetRef ref, FriendEntity friend) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet ami?'),
        content: Text('Voulez-vous supprimer ${friend.displayName} de vos amis?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await ref.read(friendsNotifierProvider.notifier).removeFriend(friend.id);
              if (context.mounted) {
                SnackbarManager.showSuccess(context, 'Ami supprime');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
