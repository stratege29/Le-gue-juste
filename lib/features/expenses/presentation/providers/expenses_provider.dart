import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/expense_entity.dart';
import '../../data/models/expense_model.dart';
import '../../../balances/domain/usecases/calculate_balances.dart';
import '../../../balances/domain/entities/balance_entity.dart';
import '../../../settlements/presentation/providers/settlements_provider.dart';

/// Stream of expenses for a group
final groupExpensesProvider =
    StreamProvider.family<List<ExpenseEntity>, String>((ref, groupId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .collection(FirebaseConstants.expensesSubcollection)
      .where(FirebaseConstants.expenseIsDeleted, isEqualTo: false)
      .orderBy(FirebaseConstants.expenseDate, descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc, groupId).toEntity())
          .toList());
});

/// Single expense by ID
final expenseProvider =
    StreamProvider.family<ExpenseEntity?, ({String groupId, String expenseId})>(
        (ref, params) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(params.groupId)
      .collection(FirebaseConstants.expensesSubcollection)
      .doc(params.expenseId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return ExpenseModel.fromFirestore(doc, params.groupId).toEntity();
  });
});

/// Group balances (calculated from expenses and settlements)
final groupBalancesProvider =
    Provider.family<Map<String, double>, String>((ref, groupId) {
  final expensesAsync = ref.watch(groupExpensesProvider(groupId));
  final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));
  final calculator = CalculateBalances();

  return expensesAsync.when(
    data: (expenses) {
      final settlements = settlementsAsync.valueOrNull ?? [];

      // Get all member IDs from expenses and settlements
      final memberIds = <String>{};
      for (final expense in expenses) {
        memberIds.add(expense.paidBy);
        memberIds.addAll(expense.participantIds);
      }
      for (final settlement in settlements) {
        memberIds.add(settlement.fromUserId);
        memberIds.add(settlement.toUserId);
      }

      return calculator.calculateGroupBalances(
        expenses: expenses,
        settlements: settlements,
        memberIds: memberIds.toList(),
      );
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Group debts (simplified transactions)
final groupDebtsProvider =
    Provider.family<List<DebtEntity>, String>((ref, groupId) {
  final balances = ref.watch(groupBalancesProvider(groupId));
  final calculator = CalculateBalances();

  return calculator.calculateDebts(
    balances: balances,
    groupId: groupId,
  );
});

/// Expenses notifier for CRUD operations
final expensesNotifierProvider =
    StateNotifierProvider<ExpensesNotifier, AsyncValue<void>>((ref) {
  return ExpensesNotifier(
    ref.watch(firestoreProvider),
    ref,
  );
});

class ExpensesNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  ExpensesNotifier(this._firestore, this._ref) : super(const AsyncValue.data(null));

  Future<String?> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required SplitType splitType,
    required List<ExpenseSplit> splits,
    DateTime? date,
    String? category,
    String currency = 'EUR',
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        state = AsyncValue.error('User not authenticated', StackTrace.current);
        return null;
      }

      final now = DateTime.now();
      final expenseId = const Uuid().v4();

      final expense = ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: description,
        amount: amount,
        currency: currency,
        paidBy: paidBy,
        createdBy: user.uid,
        createdAt: now,
        updatedAt: now,
        date: date ?? now,
        category: category,
        splitType: splitType.name,
        splits: splits.map((s) => ExpenseSplitModel.fromEntity(s)).toList(),
        isDeleted: false,
      );

      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.expensesSubcollection)
          .doc(expenseId)
          .set(expense.toFirestore());

      // Update group's updatedAt
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .update({
        FirebaseConstants.updatedAt: Timestamp.now(),
      });

      state = const AsyncValue.data(null);
      return expenseId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    String? description,
    double? amount,
    String? paidBy,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    DateTime? date,
    String? category,
  }) async {
    state = const AsyncValue.loading();

    try {
      final updates = <String, dynamic>{
        FirebaseConstants.updatedAt: Timestamp.now(),
      };

      if (description != null) {
        updates[FirebaseConstants.expenseDescription] = description;
      }
      if (amount != null) {
        updates[FirebaseConstants.expenseAmount] = amount;
      }
      if (paidBy != null) {
        updates[FirebaseConstants.expensePaidBy] = paidBy;
      }
      if (splitType != null) {
        updates[FirebaseConstants.expenseSplitType] = splitType.name;
      }
      if (splits != null) {
        final splitsMap = <String, dynamic>{};
        for (final split in splits) {
          splitsMap[split.userId] = {
            'amount': split.amount,
            'percentage': split.percentage,
            'isPaid': split.isPaid,
          };
        }
        updates[FirebaseConstants.expenseSplits] = splitsMap;
      }
      if (date != null) {
        updates[FirebaseConstants.expenseDate] = Timestamp.fromDate(date);
      }
      if (category != null) {
        updates[FirebaseConstants.expenseCategory] = category;
      }

      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.expensesSubcollection)
          .doc(expenseId)
          .update(updates);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Soft delete
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.expensesSubcollection)
          .doc(expenseId)
          .update({
        FirebaseConstants.expenseIsDeleted: true,
        FirebaseConstants.updatedAt: Timestamp.now(),
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// State for add expense form
class AddExpenseState {
  final String description;
  final double amount;
  final String? payerId;
  final SplitType splitType;
  final List<String> participantIds;
  final Map<String, double> customAmounts;
  final Map<String, double> percentages;
  final DateTime? date;
  final String? category;
  final String currency;
  final bool isLoading;
  final String? error;

  const AddExpenseState({
    this.description = '',
    this.amount = 0,
    this.payerId,
    this.splitType = SplitType.equal,
    this.participantIds = const [],
    this.customAmounts = const {},
    this.percentages = const {},
    this.date,
    this.category,
    this.currency = 'XOF',
    this.isLoading = false,
    this.error,
  });

  AddExpenseState copyWith({
    String? description,
    double? amount,
    String? payerId,
    SplitType? splitType,
    List<String>? participantIds,
    Map<String, double>? customAmounts,
    Map<String, double>? percentages,
    DateTime? date,
    String? category,
    String? currency,
    bool? isLoading,
    String? error,
  }) {
    return AddExpenseState(
      description: description ?? this.description,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      splitType: splitType ?? this.splitType,
      participantIds: participantIds ?? this.participantIds,
      customAmounts: customAmounts ?? this.customAmounts,
      percentages: percentages ?? this.percentages,
      date: date ?? this.date,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Calculate splits based on current state
  List<ExpenseSplit> calculateSplits() {
    if (participantIds.isEmpty || amount <= 0) return [];

    switch (splitType) {
      case SplitType.equal:
        return SplitCalculator.calculateEqualSplit(
          totalAmount: amount,
          participantIds: participantIds,
        );
      case SplitType.exact:
        return participantIds.map((id) {
          return ExpenseSplit(
            userId: id,
            amount: customAmounts[id] ?? 0,
          );
        }).toList();
      case SplitType.percentage:
        return SplitCalculator.calculatePercentageSplit(
          totalAmount: amount,
          percentages: percentages,
        );
    }
  }

  /// Validate the expense before saving
  String? validate() {
    if (description.trim().isEmpty) {
      return 'Description requise';
    }
    if (amount <= 0) {
      return 'Montant invalide';
    }
    if (payerId == null) {
      return 'Selectionnez qui a paye';
    }
    if (participantIds.isEmpty) {
      return 'Selectionnez au moins un participant';
    }

    final splits = calculateSplits();
    if (!SplitCalculator.validateSplits(
      totalAmount: amount,
      splits: splits,
    )) {
      return 'La somme des parts ne correspond pas au total';
    }

    return null;
  }
}

final addExpenseStateProvider =
    StateNotifierProvider.autoDispose<AddExpenseNotifier, AddExpenseState>(
        (ref) {
  return AddExpenseNotifier();
});

class AddExpenseNotifier extends StateNotifier<AddExpenseState> {
  AddExpenseNotifier() : super(const AddExpenseState());

  void setDescription(String value) {
    state = state.copyWith(description: value);
  }

  void setAmount(double value) {
    state = state.copyWith(amount: value);
  }

  void setPayer(String userId) {
    state = state.copyWith(payerId: userId);
  }

  void setSplitType(SplitType type) {
    state = state.copyWith(splitType: type);
  }

  void setParticipants(List<String> ids) {
    state = state.copyWith(participantIds: ids);
  }

  void toggleParticipant(String userId) {
    final current = List<String>.from(state.participantIds);
    if (current.contains(userId)) {
      current.remove(userId);
    } else {
      current.add(userId);
    }
    state = state.copyWith(participantIds: current);
  }

  void setCustomAmount(String userId, double amount) {
    final current = Map<String, double>.from(state.customAmounts);
    current[userId] = amount;
    state = state.copyWith(customAmounts: current);
  }

  void setPercentage(String userId, double percentage) {
    final current = Map<String, double>.from(state.percentages);
    current[userId] = percentage;
    state = state.copyWith(percentages: current);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setCategory(String? category) {
    state = state.copyWith(category: category);
  }

  void setCurrency(String currency) {
    state = state.copyWith(currency: currency);
  }

  void reset() {
    state = const AddExpenseState();
  }
}
