import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../providers/groups_provider.dart';
import '../../domain/entities/group_entity.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Groupes'),
        actions: [
          Semantics(
            label: 'Creer un nouveau groupe',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Creer un groupe',
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/groups/create');
              },
            ),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.group_outlined,
              title: 'Aucun groupe',
              description: 'Creez un groupe pour commencer a partager vos depenses',
              actionLabel: 'Creer un groupe',
              onAction: () => context.push('/groups/create'),
            );
          }
          return _buildGroupsList(context, groups);
        },
        loading: () => const SkeletonScreen(showSummaryCard: false),
        error: (error, _) => EmptyStateWidget(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Erreur de chargement',
          description: 'Impossible de charger vos groupes',
          actionLabel: 'Reessayer',
          onAction: () => ref.invalidate(userGroupsProvider),
        ),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context, List<GroupEntity> groups) {
    return Consumer(
      builder: (context, ref, _) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userGroupsProvider);
            // Wait for the refresh to complete
            await ref.read(userGroupsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _GroupCard(group: group);
            },
          ),
        );
      },
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final GroupEntity group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final balances = ref.watch(groupBalancesProvider(group.id));
    final userBalance = balances[currentUser.valueOrNull?.id] ?? 0.0;
    final currencySymbol = AppConstants.currencySymbols[group.currency] ?? group.currency;

    final isOwed = userBalance > 0.01;
    final owes = userBalance < -0.01;
    final balanceColor = isOwed ? AppColors.success : owes ? AppColors.error : AppColors.settled;
    final balanceLabel = isOwed ? 'on vous doit' : owes ? 'vous devez' : 'equilibre';
    final formattedBalance = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0).format(userBalance.abs());

    return Semantics(
      label: '${group.name}, ${group.memberCount} membres, $balanceLabel $formattedBalance',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/groups/${group.id}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Group avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: group.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            group.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.group,
                          color: AppColors.primary,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 16),
                // Group info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.memberCount} membre${group.memberCount > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.gray600,
                            ),
                      ),
                    ],
                  ),
                ),
                // Balance indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedBalance,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: balanceColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      balanceLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
