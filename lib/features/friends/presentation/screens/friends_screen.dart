import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

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
    final pendingCount = ref.watch(pendingRequestsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Amis'),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Badge(
                label: Text('$pendingCount'),
                child: IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Demandes en attente',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showPendingRequests(context, ref);
                  },
                ),
              ),
            ),
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
          if (friends.isEmpty && pendingCount == 0) {
            return EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'Aucun ami',
              description: 'Scannez le QR code d\'un ami ou partagez le votre pour commencer',
              actionLabel: 'Ajouter un ami',
              onAction: () => _showAddFriendOptions(context, ref),
            );
          }
          return _FriendsListWithRequests(
            friends: friends,
            onAddFriend: () => _showAddFriendOptions(context, ref),
            onRemoveFriend: (friend) => _showRemoveFriendDialog(context, ref, friend),
          );
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

  void _showPendingRequests(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Demandes en attente',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer(
                builder: (ctx, ref, _) {
                  final requestsAsync = ref.watch(pendingRequestsProvider);
                  return requestsAsync.when(
                    data: (requests) {
                      if (requests.isEmpty) {
                        return const Center(
                          child: Text('Aucune demande en attente'),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (ctx, index) {
                          return _PendingRequestCard(request: requests[index]);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Center(child: Text('Erreur')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFriendOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ajouter un ami',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              subtitle: const Text('Montrez votre code à un ami'),
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
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone, color: Colors.green),
              ),
              title: const Text('Numéro de téléphone'),
              subtitle: const Text('Envoyez une demande d\'ami'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showPhoneNumberDialog(context, ref);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.contacts, color: Colors.orange),
              ),
              title: const Text('Depuis mes contacts'),
              subtitle: const Text('Retrouvez vos amis sur LeGuJuste'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RouteConstants.contactsPicker);
              },
            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                    SnackbarManager.showSuccess(context, 'Ami ajouté !');
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

  void _showPhoneNumberDialog(BuildContext context, WidgetRef ref) {
    String completePhoneNumber = '';
    bool isValid = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Envoyer une demande'),
          content: IntlPhoneField(
            decoration: InputDecoration(
              hintText: 'Numéro de téléphone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            initialCountryCode: 'CI',
            languageCode: 'fr',
            autofocus: true,
            onChanged: (phone) {
              setDialogState(() {
                completePhoneNumber = phone.completeNumber;
                try {
                  isValid = phone.isValidNumber();
                } catch (_) {
                  isValid = false;
                }
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isValid
                  ? () async {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx);
                      final success = await ref
                          .read(friendsNotifierProvider.notifier)
                          .sendFriendRequest(completePhoneNumber);
                      if (context.mounted) {
                        if (success) {
                          SnackbarManager.showSuccess(context, 'Demande envoyée !');
                        } else {
                          final errorState = ref.read(friendsNotifierProvider);
                          final errorMsg = errorState.hasError
                              ? errorState.error.toString()
                              : 'Erreur lors de l\'envoi';
                          SnackbarManager.showError(context, errorMsg);
                        }
                      }
                    }
                  : null,
              child: const Text('Envoyer'),
            ),
          ],
        ),
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
                SnackbarManager.showSuccess(context, 'Ami supprimé');
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

/// Friends list with pending requests section at the top
class _FriendsListWithRequests extends ConsumerWidget {
  final List<FriendEntity> friends;
  final VoidCallback onAddFriend;
  final void Function(FriendEntity) onRemoveFriend;

  const _FriendsListWithRequests({
    required this.friends,
    required this.onAddFriend,
    required this.onRemoveFriend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRequestsProvider);
    final pendingRequests = pendingAsync.valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingRequests.isNotEmpty) ...[
          Text(
            'Demandes en attente',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...pendingRequests.map((request) => _PendingRequestCard(request: request)),
          const SizedBox(height: 16),
          if (friends.isNotEmpty)
            Text(
              'Mes amis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          if (friends.isNotEmpty) const SizedBox(height: 8),
        ],
        ...friends.map((friend) => _buildFriendCard(context, friend)),
      ],
    );
  }

  Widget _buildFriendCard(BuildContext context, FriendEntity friend) {
    final now = DateTime.now();
    final diff = now.difference(friend.addedAt);
    String dateStr;
    if (diff.inDays == 0) {
      dateStr = "aujourd'hui";
    } else if (diff.inDays == 1) {
      dateStr = 'hier';
    } else if (diff.inDays < 7) {
      dateStr = '${diff.inDays} jours';
    } else if (diff.inDays < 30) {
      dateStr = '${(diff.inDays / 7).floor()} semaines';
    } else {
      dateStr = '${(diff.inDays / 30).floor()} mois';
    }

    return Semantics(
      label: '${friend.displayName}, ami depuis $dateStr',
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
            'Ami depuis $dateStr',
            style: TextStyle(color: AppColors.gray500, fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              HapticFeedback.lightImpact();
              if (value == 'remove') {
                onRemoveFriend(friend);
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
  }
}

/// Card for a pending friend request with accept/decline buttons
class _PendingRequestCard extends ConsumerStatefulWidget {
  final FriendRequestEntity request;

  const _PendingRequestCard({required this.request});

  @override
  ConsumerState<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends ConsumerState<_PendingRequestCard> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final initial = request.fromDisplayName.isNotEmpty
        ? request.fromDisplayName[0].toUpperCase()
        : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.primary.withValues(alpha: 0.03),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          request.fromDisplayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _processing
            ? const LinearProgressIndicator()
            : Row(
                children: [
                  Flexible(
                    child: FilledButton.tonal(
                      onPressed: () => _accept(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Accepter', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextButton(
                      onPressed: () => _decline(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Refuser', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final success = await ref.read(friendsNotifierProvider.notifier).acceptFriendRequest(widget.request);

    if (!mounted) return;

    if (success) {
      SnackbarManager.showSuccess(context, '${widget.request.fromDisplayName} ajouté !');
    } else {
      setState(() => _processing = false);
      SnackbarManager.showError(context, 'Erreur');
    }
  }

  Future<void> _decline() async {
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final success = await ref.read(friendsNotifierProvider.notifier).declineFriendRequest(widget.request.id);

    if (!mounted) return;

    if (success) {
      SnackbarManager.showSuccess(context, 'Demande refusée');
    } else {
      setState(() => _processing = false);
      SnackbarManager.showError(context, 'Erreur');
    }
  }
}
