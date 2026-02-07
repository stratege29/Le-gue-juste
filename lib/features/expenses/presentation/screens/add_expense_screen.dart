import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../providers/expenses_provider.dart';

/// Screen for adding a new expense to a group
class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _initializeDefaults(List<String> memberIds, String? currentUserId) {
    if (_initialized) return;
    _initialized = true;

    // Defer provider modification to after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(addExpenseStateProvider.notifier);
      notifier.setParticipants(memberIds);
      if (currentUserId != null) {
        notifier.setPayer(currentUserId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final addExpenseState = ref.watch(addExpenseStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final memberNamesAsync = ref.watch(groupMemberNamesProvider(widget.groupId));

    group.whenData((g) {
      if (g != null) {
        _initializeDefaults(g.memberIds, currentUser.valueOrNull?.id);
      }
    });

    final memberNames = memberNamesAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle depense'),
        actions: [
          SaveButton(
            isLoading: addExpenseState.isLoading,
            onPressed: _saveExpense,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Montant'),
            const SizedBox(height: 8),
            _buildAmountField(group),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Description'),
            const SizedBox(height: 8),
            _buildDescriptionField(),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Date'),
            const SizedBox(height: 8),
            _buildDatePicker(context, addExpenseState),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Paye par'),
            const SizedBox(height: 8),
            _buildPayerChips(group, addExpenseState, currentUser, memberNames),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Repartition'),
            const SizedBox(height: 8),
            _buildSplitTypeSelector(addExpenseState),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Categorie'),
            const SizedBox(height: 8),
            _buildCategoryPicker(addExpenseState),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Pour qui'),
            const SizedBox(height: 8),
            _buildParticipantChips(group, addExpenseState, currentUser, memberNames),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildAmountField(AsyncValue group) {
    return group.when(
      data: (g) {
        final currencySymbol = g != null
            ? (AppConstants.currencySymbols[g.currency] ?? g.currency)
            : '€';
        return TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0',
            prefixText: '$currencySymbol ',
            prefixStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            ref.read(addExpenseStateProvider.notifier).setAmount(amount);
          },
        );
      },
      loading: () => const SkeletonLoader(width: double.infinity, height: 60),
      error: (_, __) => const Text('Erreur'),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Ex: Restaurant, Courses...',
      ),
      onChanged: (value) {
        ref.read(addExpenseStateProvider.notifier).setDescription(value);
      },
    );
  }

  Widget _buildPayerChips(
    AsyncValue group,
    dynamic addExpenseState,
    AsyncValue currentUser,
    Map<String, String> memberNames,
  ) {
    return group.when(
      data: (g) {
        if (g == null) return const SizedBox();
        return Wrap(
          spacing: 8,
          children: g.memberIds.map<Widget>((memberId) {
            final isSelected = addExpenseState.payerId == memberId;
            final isCurrentUser = memberId == currentUser.valueOrNull?.id;
            final displayName = isCurrentUser
                ? 'Moi'
                : (memberNames[memberId] ?? 'Utilisateur');
            return Semantics(
              label: 'Payeur: $displayName',
              selected: isSelected,
              child: ChoiceChip(
                label: Text(displayName),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  ref.read(addExpenseStateProvider.notifier).setPayer(memberId);
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SkeletonLoader(width: 200, height: 32),
      error: (_, __) => const Text('Erreur'),
    );
  }

  Widget _buildSplitTypeSelector(dynamic addExpenseState) {
    return Semantics(
      label: 'Methode de repartition',
      child: SegmentedButton<SplitType>(
        segments: const [
          ButtonSegment(
            value: SplitType.equal,
            label: Text('Egal'),
            icon: Icon(Icons.drag_handle),
          ),
          ButtonSegment(
            value: SplitType.exact,
            label: Text('Montants'),
            icon: Icon(Icons.attach_money),
          ),
          ButtonSegment(
            value: SplitType.percentage,
            label: Text('%'),
            icon: Icon(Icons.percent),
          ),
        ],
        selected: {addExpenseState.splitType},
        onSelectionChanged: (selected) {
          HapticFeedback.selectionClick();
          ref.read(addExpenseStateProvider.notifier).setSplitType(selected.first);
        },
      ),
    );
  }

  Widget _buildParticipantChips(
    AsyncValue group,
    dynamic addExpenseState,
    AsyncValue currentUser,
    Map<String, String> memberNames,
  ) {
    return group.when(
      data: (g) {
        if (g == null) return const SizedBox();
        return Wrap(
          spacing: 8,
          children: g.memberIds.map<Widget>((memberId) {
            final isSelected = addExpenseState.participantIds.contains(memberId);
            final isCurrentUser = memberId == currentUser.valueOrNull?.id;
            final displayName = isCurrentUser
                ? 'Moi'
                : (memberNames[memberId] ?? 'Utilisateur');
            return Semantics(
              label: 'Participant: $displayName',
              selected: isSelected,
              child: FilterChip(
                label: Text(displayName),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  ref.read(addExpenseStateProvider.notifier).toggleParticipant(memberId);
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SkeletonLoader(width: 200, height: 32),
      error: (_, __) => const Text('Erreur'),
    );
  }

  Widget _buildDatePicker(BuildContext context, dynamic addExpenseState) {
    final selectedDate = addExpenseState.date as DateTime?;
    final now = DateTime.now();
    String displayText;
    if (selectedDate != null &&
        !(selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day)) {
      displayText = DateFormat.yMMMMd('fr_FR').format(selectedDate);
    } else {
      displayText = "Aujourd'hui";
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: Text(displayText),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? now,
          firstDate: DateTime(2020),
          lastDate: now,
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) {
          HapticFeedback.selectionClick();
          ref.read(addExpenseStateProvider.notifier).setDate(picked);
        }
      },
    );
  }

  Widget _buildCategoryPicker(dynamic addExpenseState) {
    final selectedCategory = addExpenseState.category as String?;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.all.map<Widget>((category) {
        final isSelected = selectedCategory == category;
        return FilterChip(
          label: Text(ExpenseCategory.getDisplayName(category)),
          selected: isSelected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            ref.read(addExpenseStateProvider.notifier).setCategory(
                  isSelected ? null : category,
                );
          },
        );
      }).toList(),
    );
  }

  void _saveExpense() async {
    HapticFeedback.mediumImpact();
    final state = ref.read(addExpenseStateProvider);
    final error = state.validate();

    if (error != null) {
      SnackbarManager.showError(context, error);
      return;
    }

    final expenseId = await ref.read(expensesNotifierProvider.notifier).createExpense(
      groupId: widget.groupId,
      description: state.description,
      amount: state.amount,
      paidBy: state.payerId!,
      splitType: state.splitType,
      splits: state.calculateSplits(),
      date: state.date,
      category: state.category,
    );

    if (expenseId != null && mounted) {
      ref.read(addExpenseStateProvider.notifier).reset();
      Navigator.pop(context);
      SnackbarManager.showSuccess(context, 'Depense ajoutee!');
    }
  }
}
