import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/wave_service.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../balances/domain/entities/balance_entity.dart';
import '../providers/settlements_provider.dart';
import '../widgets/payment_method_bottom_sheet.dart';

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
    final debtsAsync = ref.watch(groupDebtsProvider(widget.groupId));
    final memberNamesAsync = ref.watch(groupMemberNamesProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider);

    // Single consolidated loading check across all async providers
    final isLoading = groupAsync.isLoading ||
        debtsAsync.isLoading ||
        memberNamesAsync.isLoading ||
        currentUser.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rembourser'),
      ),
      body: isLoading
          ? const SkeletonScreen(itemCount: 3, showSummaryCard: true)
          : groupAsync.when(
              data: (group) {
                if (group == null) {
                  return const Center(child: Text('Gazoil non trouvé'));
                }

                final user = currentUser.valueOrNull;
                if (user == null) {
                  return const Center(child: Text('Non connecté'));
                }

                // A debts error must never be shown as "nothing to settle":
                // surface it with a retry instead of fabricated empty data.
                if (debtsAsync.hasError) {
                  return EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Une erreur est survenue',
                    description: 'Impossible de charger les remboursements',
                    actionLabel: 'Réessayer',
                    onAction: () {
                      ref.invalidate(groupExpensesProvider(widget.groupId));
                      ref.invalidate(groupSettlementsProvider(widget.groupId));
                    },
                    iconColor: AppColors.error,
                  );
                }
                final debts = debtsAsync.valueOrNull ?? const <DebtEntity>[];

                final memberNames = memberNamesAsync.valueOrNull ?? {};
                final currencySymbol =
                    AppConstants.currencySymbols[group.currency] ?? group.currency;

                // Filter debts where current user is involved
                final myDebts = debts
                    .where((d) =>
                        d.fromUserId == user.id || d.toUserId == user.id)
                    .toList();

                if (myDebts.isEmpty) {
                  return const AllSettledStateWidget(
                    subtitle: 'Aucun remboursement nécessaire dans ce gazoil',
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
                          'Sélectionnez un remboursement',
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
                              group.currency,
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
              loading: () => const SkeletonScreen(itemCount: 3),
              error: (error, _) => EmptyStateWidget(
                icon: Icons.error_outline,
                title: 'Une erreur est survenue',
                description: 'Impossible de charger les données',
                actionLabel: 'Réessayer',
                onAction: () => ref.invalidate(groupProvider(widget.groupId)),
                iconColor: AppColors.error,
              ),
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
    String currency,
    String currentUserId,
    bool isSelected,
  ) {
    final isOwing = debt.fromUserId == currentUserId;
    final otherUserId = isOwing ? debt.toUserId : debt.fromUserId;
    final otherUserName = memberNames[otherUserId] ?? 'Utilisateur';

    // Currency-aware decimals: whole units for XOF, 2 decimals for EUR...
    final formattedAmount = CurrencyFormat.format(debt.amount, currency);

    return Semantics(
      label: isOwing
          ? 'Vous devez $formattedAmount à $otherUserName'
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
                            ? 'Vous devez à $otherUserName'
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
                            : 'Marquez comme remboursé',
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

  Future<void> _showSettleDialog(BuildContext context) async {
    if (_selectedDebt == null) return;

    final method = await PaymentMethodBottomSheet.show(context);
    if (method == null || !context.mounted) return;

    if (method == PaymentMethod.wave) {
      await _handleWavePayment(context);
    } else {
      _showManualSettleDialog(context);
    }
  }

  Future<void> _handleWavePayment(BuildContext context) async {
    final debt = _selectedDebt!;
    final groupAsync = ref.read(groupProvider(widget.groupId));
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final isOwing = debt.fromUserId == currentUser.id;
    final recipientId = isOwing ? debt.toUserId : debt.fromUserId;

    // Fetch recipient phone number from Firestore
    final userDoc = await ref
        .read(firestoreProvider)
        .collection(FirebaseConstants.usersCollection)
        .doc(recipientId)
        .get();

    if (!context.mounted) return;

    final phoneNumber = userDoc.data()?['phoneNumber'] as String?;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Numéro de téléphone du destinataire introuvable'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    // Wave deep links only accept whole integer amounts (Wave operates on
    // XOF, a zero-decimal currency). Round ONCE and use that same value
    // for the Wave request AND the recorded settlement, so the ledger
    // matches what was actually requested in Wave.
    final waveAmount = debt.amount.round();
    final launched = await WaveService.launchWavePayment(
      phoneNumber: phoneNumber,
      amount: waveAmount,
    );

    if (!context.mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Wave'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    // After returning from Wave, ask for confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paiement Wave'),
        content: const Text('Avez-vous effectué le paiement via Wave ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: const Text('Oui, c\'est fait'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final currency = groupAsync.valueOrNull?.currency ?? 'XOF';
    final success = await ref
        .read(settlementsNotifierProvider.notifier)
        .createSettlement(
          groupId: widget.groupId,
          fromUserId: debt.fromUserId,
          toUserId: debt.toUserId,
          amount: waveAmount.toDouble(),
          currency: currency,
          note: 'Paiement Wave',
          paymentMethod: PaymentMethod.wave,
        );

    if (!context.mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Paiement Wave enregistré !'),
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
  }

  void _showManualSettleDialog(BuildContext context) {
    final debt = _selectedDebt!;
    final groupAsync = ref.read(groupProvider(widget.groupId));
    final memberNames = ref.read(groupMemberNamesProvider(widget.groupId));
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    if (currentUser == null) return;

    final isOwing = debt.fromUserId == currentUser.id;
    final otherUserId = isOwing ? debt.toUserId : debt.fromUserId;
    final otherUserName =
        memberNames.valueOrNull?[otherUserId] ?? 'Utilisateur';
    final groupCurrency = groupAsync.valueOrNull?.currency ?? 'EUR';
    final currencySymbol =
        AppConstants.currencySymbols[groupCurrency] ?? groupCurrency;

    final amountController = TextEditingController(
        text: CurrencyFormat.forInput(debt.amount, groupCurrency));
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
                hintText: 'Ex : Virement, espèces...',
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

              final note = noteController.text.isNotEmpty
                  ? noteController.text
                  : null;
              final currency = groupAsync.valueOrNull?.currency ?? 'EUR';

              if (ctx.mounted) Navigator.pop(ctx);

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

              if (!context.mounted) return;

              if (success) {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Remboursement enregistré !'),
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
    ).whenComplete(() {
      // The controllers are only read before the dialog is popped, so it is
      // safe (and required, to avoid leaks) to dispose them once it closes.
      amountController.dispose();
      noteController.dispose();
    });
  }

}
