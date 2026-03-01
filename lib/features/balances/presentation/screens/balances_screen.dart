import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../settlements/presentation/providers/settlements_provider.dart';

class BalancesScreen extends ConsumerWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final currentAuthUser = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Soldes'),
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Aucun groupe',
              description: 'Rejoignez un groupe pour voir vos soldes',
            );
          }

          final userId = currentAuthUser.valueOrNull?.uid;
          if (userId == null) {
            return const SkeletonScreen(itemCount: 3);
          }

          // Check if any expenses are still loading
          bool isLoading = false;
          for (final group in groups) {
            final expensesAsync = ref.watch(groupExpensesProvider(group.id));
            if (expensesAsync.isLoading) {
              isLoading = true;
              break;
            }
          }

          if (isLoading) {
            return const SkeletonScreen(itemCount: 3);
          }

          // Calculate total balance per currency across all groups
          final totalsByCurrency = <String, double>{};
          final groupBalances = <_GroupBalanceInfo>[];

          for (final group in groups) {
            final balances = ref.watch(groupBalancesProvider(group.id));
            final userBalance = balances[userId] ?? 0.0;
            totalsByCurrency[group.currency] =
                (totalsByCurrency[group.currency] ?? 0) + userBalance;

            if (userBalance.abs() > 0.01) {
              final currencySymbol = AppConstants.currencySymbols[group.currency] ?? group.currency;
              groupBalances.add(_GroupBalanceInfo(
                groupName: group.name,
                groupId: group.id,
                balance: userBalance,
                currency: group.currency,
                currencySymbol: currencySymbol,
              ));
            }
          }

          // Find the primary currency (most used) for the summary card
          final primaryCurrency = totalsByCurrency.keys.isEmpty
              ? AppConstants.defaultCurrency
              : totalsByCurrency.keys.reduce((a, b) =>
                  (totalsByCurrency[a]?.abs() ?? 0) >= (totalsByCurrency[b]?.abs() ?? 0) ? a : b);
          final primarySymbol = AppConstants.currencySymbols[primaryCurrency] ?? primaryCurrency;
          final primaryTotal = totalsByCurrency[primaryCurrency] ?? 0;
          final hasMultipleCurrencies = totalsByCurrency.length > 1;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userGroupsProvider);
              await ref.read(userGroupsProvider.future);
            },
            child: Column(
              children: [
                // Total balance card per currency
                if (hasMultipleCurrencies)
                  ...totalsByCurrency.entries
                      .where((e) => e.value.abs() > 0.01)
                      .map((e) {
                    final sym = AppConstants.currencySymbols[e.key] ?? e.key;
                    return SummaryCard.balance(
                      amount: e.value,
                      currencySymbol: sym,
                      subtitle: e.value > 0.01
                          ? 'Récupérez votre argent !'
                          : e.value < -0.01
                              ? 'Pensez à rembourser'
                              : 'Tout est équilibré',
                    );
                  })
                else
                  SummaryCard.balance(
                    amount: primaryTotal,
                    currencySymbol: primarySymbol,
                    subtitle: primaryTotal > 0.01
                        ? 'Récupérez votre argent !'
                        : primaryTotal < -0.01
                            ? 'Pensez à rembourser'
                            : 'Tout est équilibré',
                  ),
                // Balances list by group
                Expanded(
                  child: groupBalances.isEmpty
                      ? ListView(
                          children: const [
                            AllSettledStateWidget(
                              subtitle: 'Vous n\'avez aucune dette en cours',
                            ),
                          ],
                        )
                      : _buildBalancesList(context, ref, groupBalances, userId),
                ),
              ],
            ),
          );
        },
        loading: () => const SkeletonScreen(itemCount: 3),
        error: (_, __) => const EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Erreur',
          description: 'Impossible de charger vos groupes',
        ),
      ),
    );
  }

  Widget _buildBalancesList(
    BuildContext context,
    WidgetRef ref,
    List<_GroupBalanceInfo> balances,
    String currentUserId,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: balances.length,
      itemBuilder: (context, index) {
        final info = balances[index];
        final isPositive = info.balance > 0;
        final formattedAmount = NumberFormat.currency(
          symbol: info.currencySymbol,
          decimalDigits: 2,
        ).format(info.balance.abs());

        // Get debts for this group
        final debts = ref.watch(groupDebtsProvider(info.groupId));
        final memberNames = ref.watch(groupMemberNamesProvider(info.groupId)).valueOrNull ?? {};

        // Filter debts relevant to current user
        final userDebts = debts.where(
          (d) => d.fromUserId == currentUserId || d.toUserId == currentUserId
        ).toList();

        return StaggeredAnimatedCard(
          index: index,
          child: Semantics(
            label: '${info.groupName}: ${isPositive ? "on vous doit" : "vous devez"} $formattedAmount',
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: isPositive ? AppColors.success : AppColors.error,
                    width: 3,
                  ),
                ),
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: IconBadge.balance(isPositive: isPositive),
                  title: Text(
                    info.groupName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isPositive ? 'On vous doit' : 'Vous devez',
                    style: TextStyle(
                      color: isPositive ? AppColors.success : AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Text(
                    formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                  children: userDebts.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucun détail disponible'),
                          ),
                        ]
                      : userDebts.map((debt) {
                          final isUserDebtor = debt.fromUserId == currentUserId;
                          final otherUserId = isUserDebtor ? debt.toUserId : debt.fromUserId;
                          final otherUserName = memberNames[otherUserId] ?? 'Utilisateur';
                          final amount = NumberFormat.currency(
                            symbol: info.currencySymbol,
                            decimalDigits: 2,
                          ).format(debt.amount);

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isUserDebtor ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isUserDebtor ? AppColors.error : AppColors.success,
                              size: 20,
                            ),
                            title: Text(
                              isUserDebtor
                                  ? 'Vous devez $amount à $otherUserName'
                                  : '$otherUserName vous doit $amount',
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showSettleDialog(
                                  context,
                                  ref,
                                  groupId: info.groupId,
                                  fromUserId: debt.fromUserId,
                                  toUserId: debt.toUserId,
                                  amount: debt.amount,
                                  currency: info.currency,
                                  currencySymbol: info.currencySymbol,
                                  otherUserName: otherUserName,
                                  isUserDebtor: isUserDebtor,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                                foregroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Régler'),
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSettleDialog(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String currency,
    required String currencySymbol,
    required String otherUserName,
    required bool isUserDebtor,
  }) {
    final formattedAmount = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    ).format(amount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le règlement'),
        content: Text(
          isUserDebtor
              ? 'Confirmer que vous avez payé $formattedAmount à $otherUserName ?'
              : 'Confirmer que $otherUserName vous a payé $formattedAmount ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _settleDebt(
                context,
                ref,
                groupId: groupId,
                fromUserId: fromUserId,
                toUserId: toUserId,
                amount: amount,
                currency: currency,
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _settleDebt(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String currency,
  }) async {
    try {
      await ref.read(settlementsNotifierProvider.notifier).createSettlement(
        groupId: groupId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        currency: currency,
      );
      if (context.mounted) {
        HapticFeedback.mediumImpact();
        SnackbarManager.showSuccess(context, 'Dette réglée !');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarManager.showError(context, 'Erreur: $e');
      }
    }
  }
}

class _GroupBalanceInfo {
  final String groupName;
  final String groupId;
  final double balance;
  final String currency;
  final String currencySymbol;

  _GroupBalanceInfo({
    required this.groupName,
    required this.groupId,
    required this.balance,
    required this.currency,
    required this.currencySymbol,
  });
}
