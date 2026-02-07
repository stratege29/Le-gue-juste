import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../balances/domain/entities/balance_entity.dart';
import '../providers/settlements_provider.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final String groupId;

  const SettleUpScreen({super.key, required this.groupId});

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  DebtEntity? _selectedDebt;

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final debts = ref.watch(groupDebtsProvider(widget.groupId));
    final memberNamesAsync = ref.watch(groupMemberNamesProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rembourser'),
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Groupe non trouve'));
          }

          final currencySymbol =
              AppConstants.currencySymbols[group.currency] ?? group.currency;

          return memberNamesAsync.when(
            data: (memberNames) {
              return currentUser.when(
                data: (user) {
                  if (user == null) {
                    return const Center(child: Text('Non connecte'));
                  }

                  // Filter debts where current user is involved
                  final myDebts = debts.where((d) =>
                      d.fromUserId == user.id || d.toUserId == user.id).toList();

                  if (myDebts.isEmpty) {
                    return const AllSettledStateWidget(
                      subtitle: 'Aucun remboursement necessaire dans ce groupe',
                    );
                  }

                  // Calculate totals for summary
                  double totalOwed = 0;
                  double totalOwing = 0;
                  for (final debt in myDebts) {
                    if (debt.fromUserId == user.id) {
                      totalOwing += debt.amount;
                    } else {
                      totalOwed += debt.amount;
                    }
                  }

                  return RadioGroup<DebtEntity>(
                    groupValue: _selectedDebt,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDebt = value;
                      });
                    },
                    child: Column(
                      children: [
                        // Debts summary
                        DebtSummaryCard(
                          totalOwing: totalOwing,
                          totalOwed: totalOwed,
                          currencySymbol: currencySymbol,
                        ),
                        const SizedBox(height: 16),
                        // Select debt to settle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Selectionnez un remboursement',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Debt cards
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: myDebts.length,
                            itemBuilder: (context, index) {
                              final debt = myDebts[index];
                              final isSelected = _selectedDebt == debt;
                              return _buildDebtCard(
                                context,
                                debt,
                                memberNames,
                                currencySymbol,
                                user.id,
                                isSelected,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Erreur')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Erreur')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur: $error')),
      ),
      bottomNavigationBar: _selectedDebt != null
          ? _buildSettleButton(context)
          : null,
    );
  }

  Widget _buildDebtCard(
    BuildContext context,
    DebtEntity debt,
    Map<String, String> memberNames,
    String currencySymbol,
    String currentUserId,
    bool isSelected,
  ) {
    final isOwing = debt.fromUserId == currentUserId;
    final otherUserId = isOwing ? debt.toUserId : debt.fromUserId;
    final otherUserName = memberNames[otherUserId] ?? 'Utilisateur';

    final formattedAmount =
        '$currencySymbol${NumberFormat('#,##0').format(debt.amount)}';

    return Semantics(
      label: isOwing
          ? 'Vous devez $formattedAmount a $otherUserName'
          : '$otherUserName vous doit $formattedAmount',
      selected: isSelected,
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDebt = isSelected ? null : debt;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconBadge.balance(isPositive: !isOwing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwing
                            ? 'Vous devez a $otherUserName'
                            : '$otherUserName vous doit',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOwing
                            ? 'Remboursez cette dette'
                            : 'Marquez comme rembourse',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isOwing ? AppColors.error : AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Radio<DebtEntity>(
                  value: debt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettleButton(BuildContext context) {
    return Semantics(
      label: 'Confirmer le remboursement',
      button: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56, // Minimum touch target
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showSettleDialog(context);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmer le remboursement'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettleDialog(BuildContext context) {
    if (_selectedDebt == null) return;

    final groupAsync = ref.read(groupProvider(widget.groupId));
    final memberNames = ref.read(groupMemberNamesProvider(widget.groupId));
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    if (currentUser == null) return;

    final debt = _selectedDebt!;
    final isOwing = debt.fromUserId == currentUser.id;
    final otherUserId = isOwing ? debt.toUserId : debt.fromUserId;
    final otherUserName =
        memberNames.valueOrNull?[otherUserId] ?? 'Utilisateur';
    final currencySymbol = groupAsync.valueOrNull != null
        ? AppConstants.currencySymbols[groupAsync.valueOrNull!.currency] ??
            groupAsync.valueOrNull!.currency
        : 'EUR';

    final amountController =
        TextEditingController(text: debt.amount.toStringAsFixed(2));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le remboursement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOwing
                  ? 'Vous remboursez $otherUserName'
                  : '$otherUserName vous rembourse',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant',
                prefixText: '$currencySymbol ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Ex: Virement, especes...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final amount =
                  double.tryParse(amountController.text.replaceAll(',', '.')) ??
                      0;
              if (amount <= 0) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Montant invalide'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                return;
              }

              // Store note before closing dialog
              final note = noteController.text.isNotEmpty
                  ? noteController.text
                  : null;
              final currency = groupAsync.valueOrNull?.currency ?? 'EUR';

              // Close dialog first
              if (ctx.mounted) Navigator.pop(ctx);

              // Then perform async operation
              final success = await ref
                  .read(settlementsNotifierProvider.notifier)
                  .createSettlement(
                    groupId: widget.groupId,
                    fromUserId: debt.fromUserId,
                    toUserId: debt.toUserId,
                    amount: amount,
                    currency: currency,
                    note: note,
                  );

              // Check if screen is still mounted before navigation
              if (!context.mounted) return;

              if (success) {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Remboursement enregistre!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                Navigator.pop(context);
              } else {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Erreur lors de l\'enregistrement'),
                      backgroundColor: AppColors.error,
                    ),
                  );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

}
