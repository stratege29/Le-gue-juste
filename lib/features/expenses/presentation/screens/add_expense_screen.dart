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
    for (final c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeDefaults(List<String> memberIds, String? currentUserId, String? groupCurrency) {
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
      if (groupCurrency != null) {
        notifier.setCurrency(groupCurrency);
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
        _initializeDefaults(g.memberIds, currentUser.valueOrNull?.id, g.currency);
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
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Pour qui'),
            const SizedBox(height: 8),
            _buildParticipantChips(group, addExpenseState, currentUser, memberNames),
            if (addExpenseState.splitType != SplitType.equal) ...[
              const SizedBox(height: 12),
              _buildCustomSplitInputs(addExpenseState, currentUser, memberNames),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Categorie'),
            const SizedBox(height: 8),
            _buildCategoryPicker(addExpenseState),
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
    final addExpenseState = ref.watch(addExpenseStateProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Currency dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: addExpenseState.currency,
              isDense: true,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              items: AppConstants.currencySymbols.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.value} (${entry.key})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  HapticFeedback.selectionClick();
                  ref.read(addExpenseStateProvider.notifier).setCurrency(value);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Amount field
        Expanded(
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: false,
            ),
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0;
              ref.read(addExpenseStateProvider.notifier).setAmount(amount);
            },
          ),
        ),
      ],
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
                label: Text(
                  displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.grey.shade200,
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
                label: Text(
                  displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.grey.shade200,
                checkmarkColor: Colors.white,
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

  final Map<String, TextEditingController> _splitControllers = {};

  TextEditingController _getSplitController(String userId) {
    return _splitControllers.putIfAbsent(userId, () => TextEditingController());
  }

  Widget _buildCustomSplitInputs(
    dynamic addExpenseState,
    AsyncValue currentUser,
    Map<String, String> memberNames,
  ) {
    final participants = addExpenseState.participantIds as List<String>;
    final isExact = addExpenseState.splitType == SplitType.exact;
    final suffix = isExact ? '€' : '%';
    final total = isExact ? addExpenseState.amount as double : 100.0;
    // Calculate entered sum and how many fields are empty
    double enteredSum = 0;
    int emptyCount = 0;
    for (final id in participants) {
      final controller = _getSplitController(id);
      if (controller.text.isNotEmpty) {
        enteredSum += double.tryParse(controller.text) ?? 0;
      } else {
        emptyCount++;
      }
    }
    final remaining = total - enteredSum;
    final suggestion = emptyCount > 0
        ? (remaining / emptyCount).clamp(0, double.infinity)
        : 0.0;

    return Column(
      children: [
        ...participants.map<Widget>((userId) {
          final isCurrentUser = userId == currentUser.valueOrNull?.id;
          final displayName = isCurrentUser
              ? 'Moi'
              : (memberNames[userId] ?? 'Utilisateur');
          final controller = _getSplitController(userId);
          final hasValue = controller.text.isNotEmpty;
          final suggestionText = !hasValue && suggestion > 0
              ? suggestion.toStringAsFixed(2)
              : (isExact ? 'Montant' : '%');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: suggestionText,
                      hintStyle: TextStyle(
                        color: !hasValue && suggestion > 0
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                        fontStyle: !hasValue && suggestion > 0
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      suffixText: suffix,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value) ?? 0;
                      if (isExact) {
                        ref.read(addExpenseStateProvider.notifier).setCustomAmount(userId, parsed);
                      } else {
                        ref.read(addExpenseStateProvider.notifier).setPercentage(userId, parsed);
                      }
                      // Trigger rebuild for suggestion updates
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        if (isExact && addExpenseState.amount > 0) ...[
          const SizedBox(height: 4),
          Text(
            remaining >= 0
                ? 'Restant: ${remaining.toStringAsFixed(2)} $suffix'
                : 'Depassement: ${(-remaining).toStringAsFixed(2)} $suffix',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: remaining < 0 ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ],
      ],
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
          label: Text(
            ExpenseCategory.getDisplayName(category),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade800,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey.shade200,
          checkmarkColor: Colors.white,
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

    // Apply suggestions to empty fields before saving
    final currentState = ref.read(addExpenseStateProvider);
    if (currentState.splitType == SplitType.exact) {
      double enteredSum = 0;
      int emptyCount = 0;
      for (final id in currentState.participantIds) {
        final controller = _getSplitController(id);
        if (controller.text.isNotEmpty) {
          enteredSum += double.tryParse(controller.text) ?? 0;
        } else {
          emptyCount++;
        }
      }
      if (emptyCount > 0) {
        final remaining = currentState.amount - enteredSum;
        final suggestion = remaining / emptyCount;
        for (final id in currentState.participantIds) {
          final controller = _getSplitController(id);
          if (controller.text.isEmpty) {
            ref.read(addExpenseStateProvider.notifier).setCustomAmount(id, suggestion);
          }
        }
      }
    } else if (currentState.splitType == SplitType.percentage) {
      double enteredSum = 0;
      int emptyCount = 0;
      for (final id in currentState.participantIds) {
        final controller = _getSplitController(id);
        if (controller.text.isNotEmpty) {
          enteredSum += double.tryParse(controller.text) ?? 0;
        } else {
          emptyCount++;
        }
      }
      if (emptyCount > 0) {
        final remaining = 100.0 - enteredSum;
        final suggestion = remaining / emptyCount;
        for (final id in currentState.participantIds) {
          final controller = _getSplitController(id);
          if (controller.text.isEmpty) {
            ref.read(addExpenseStateProvider.notifier).setPercentage(id, suggestion);
          }
        }
      }
    }

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
      currency: state.currency,
    );

    if (expenseId != null && mounted) {
      ref.read(addExpenseStateProvider.notifier).reset();
      Navigator.pop(context);
      SnackbarManager.showSuccess(context, 'Depense ajoutee!');
    }
  }
}
