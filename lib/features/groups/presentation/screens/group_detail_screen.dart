import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/groups_provider.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../balances/domain/entities/balance_entity.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final balances = ref.watch(groupBalancesProvider(groupId));
    final debts = ref.watch(groupDebtsProvider(groupId));
    final currentAuthUser = ref.watch(authStateProvider);
    final memberNamesAsync = ref.watch(groupMemberNamesProvider(groupId));

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Groupe non trouve')),
          );
        }

        // Use Firebase Auth UID directly for balance lookup (more reliable)
        final authUid = currentAuthUser.valueOrNull?.uid;
        final userBalance = authUid != null ? (balances[authUid] ?? 0.0) : 0.0;
        final isBalancesLoading = expensesAsync.isLoading || authUid == null;
        final currencySymbol = AppConstants.currencySymbols[group.currency] ?? group.currency;
        final memberNames = memberNamesAsync.valueOrNull ?? {};

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              Semantics(
                label: 'Inviter des membres',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Inviter des membres',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showInviteDialog(context, ref, group.name);
                  },
                ),
              ),
              Semantics(
                label: 'Parametres du groupe',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Parametres du groupe',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showGroupSettings(context, ref, group.name, group.id);
                  },
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Balance summary card
              _buildBalanceSummary(
                context,
                userBalance,
                debts,
                currencySymbol,
                memberNames,
                authUid,
                isBalancesLoading,
              ),
              // Expenses list
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return _buildExpensesList(context, expenses, currencySymbol, memberNames, groupId);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur: $error')),
                ),
              ),
            ],
          ),
          floatingActionButton: Semantics(
            label: 'Ajouter une depense',
            button: true,
            child: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showAddExpenseSheet(context, ref, groupId);
              },
              icon: const Icon(Icons.add),
              label: const Text('Depense'),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur: $error')),
      ),
    );
  }

  Widget _buildBalanceSummary(
    BuildContext context,
    double userBalance,
    List<DebtEntity> debts,
    String currencySymbol,
    Map<String, String> memberNames,
    String? currentUserId,
    bool isLoading,
  ) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isOwed = userBalance > 0.01;
    final owes = userBalance < -0.01;

    // Filter debts relevant to current user
    final userDebts = currentUserId != null
        ? debts.where((d) => d.fromUserId == currentUserId || d.toUserId == currentUserId).toList()
        : <DebtEntity>[];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwed
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : owes
                  ? [AppColors.error, AppColors.error.withValues(alpha: 0.8)]
                  : [AppColors.gray500, AppColors.gray600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            isOwed
                ? 'On vous doit'
                : owes
                    ? 'Vous devez'
                    : 'Solde equilibre',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2).format(userBalance.abs()),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          // Show debt details
          if (userDebts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white30, height: 1),
            const SizedBox(height: 12),
            ...userDebts.map((debt) {
              final isUserDebtor = debt.fromUserId == currentUserId;
              final otherUserId = isUserDebtor ? debt.toUserId : debt.fromUserId;
              final otherUserName = memberNames[otherUserId] ?? 'Utilisateur';
              final amount = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2).format(debt.amount);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUserDebtor ? Icons.arrow_forward : Icons.arrow_back,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUserDebtor
                          ? 'Vous devez $amount a $otherUserName'
                          : '$otherUserName vous doit $amount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            if (owes)
              ElevatedButton.icon(
                onPressed: () => context.push('/groups/$groupId/settle'),
                icon: const Icon(Icons.handshake, size: 18),
                label: const Text('Rembourser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: AppColors.gray400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune depense',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gray600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez une depense pour commencer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(BuildContext context, List<ExpenseEntity> expenses, String currencySymbol, Map<String, String> memberNames, String groupId) {
    // Group expenses by date
    final groupedExpenses = <String, List<ExpenseEntity>>{};
    for (final expense in expenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedExpenses.length,
      itemBuilder: (context, index) {
        final dateKey = groupedExpenses.keys.elementAt(index);
        final dateExpenses = groupedExpenses[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _formatDateHeader(date),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gray600,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...dateExpenses.map<Widget>((expense) => _ExpenseCard(
              expense: expense,
              currencySymbol: currencySymbol,
              memberNames: memberNames,
              groupId: groupId,
            )),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Aujourd\'hui';
    } else if (expenseDate == yesterday) {
      return 'Hier';
    } else {
      return DateFormat('EEEE d MMMM', 'fr_FR').format(date);
    }
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref, String groupName) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inviter des membres',
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
                child: const Icon(Icons.qr_code, color: AppColors.primary),
              ),
              title: const Text('Scanner un QR code'),
              subtitle: const Text('Ajoutez un ami present'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final currentGroupId = groupId;
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.push('/scan', extra: currentGroupId);
                  }
                });
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share, color: AppColors.secondary),
              ),
              title: const Text('Partager un lien'),
              subtitle: const Text('Envoyez une invitation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final shareText = 'Rejoins mon groupe "$groupName" sur LeGuJuste pour partager nos depenses!\n\nTelecharge l\'app et scanne mon QR code pour rejoindre le groupe.';
                final shareSubject = 'Invitation au groupe $groupName';
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Share.share(shareText, subject: shareSubject);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupSettings(BuildContext context, WidgetRef ref, String groupName, String groupId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Parametres du groupe',
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
                child: const Icon(Icons.edit, color: AppColors.primary),
              ),
              title: const Text('Modifier le groupe'),
              subtitle: Text(groupName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showEditGroupDialog(context, ref, groupId, groupName);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.exit_to_app, color: AppColors.error),
              ),
              title: const Text('Quitter le groupe'),
              subtitle: const Text('Vous ne verrez plus ce groupe'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showLeaveGroupConfirm(context, ref, groupId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, WidgetRef ref, String groupId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom du groupe',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(groupsNotifierProvider.notifier).updateGroup(
                  groupId: groupId,
                  name: controller.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Sauver'),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupConfirm(BuildContext context, WidgetRef ref, String groupId) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le groupe?'),
        content: const Text('Vous ne pourrez plus voir les depenses de ce groupe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (currentUser != null) {
                await ref.read(groupsNotifierProvider.notifier).removeMember(
                  groupId: groupId,
                  userId: currentUser.id,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  context.go('/groups');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref, String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(groupId: groupId),
        fullscreenDialog: true,
      ),
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  final ExpenseEntity expense;
  final String currencySymbol;
  final Map<String, String> memberNames;
  final String groupId;

  const _ExpenseCard({
    required this.expense,
    required this.currencySymbol,
    required this.memberNames,
    required this.groupId,
  });

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette depense?'),
        content: Text(
          'La depense "${expense.description}" sera supprimee definitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref.read(expensesNotifierProvider.notifier).deleteExpense(
      groupId: groupId,
      expenseId: expense.id,
    );
    if (context.mounted) {
      SnackbarManager.showSuccess(context, 'Depense supprimee');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paidByName = memberNames[expense.paidBy] ?? 'Utilisateur';
    final formattedAmount = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    ).format(expense.amount);

    final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwner = currentUserId != null && expense.createdBy == currentUserId;

    return Semantics(
      label: '${expense.description}, $formattedAmount, paye par $paidByName',
      child: Dismissible(
        key: ValueKey(expense.id),
        direction: isOwner
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _deleteExpense(context, ref),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: IconBadge.category(expense.category),
            title: Text(
              expense.description,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Paye par $paidByName',
              style: TextStyle(color: AppColors.gray600, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedAmount,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppColors.gray500,
                      size: 20,
                    ),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await _confirmDelete(context);
                        if (confirmed == true && context.mounted) {
                          await _deleteExpense(context, ref);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
