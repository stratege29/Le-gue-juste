import '../entities/balance_entity.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../settlements/domain/entities/settlement_entity.dart';

/// Rounds [value] to the number of decimals used by [currency]
/// (0 for XOF/XAF, 2 otherwise).
double _roundForCurrency(double value, String currency) {
  final digits = CurrencyFormat.decimalDigits(currency);
  return double.parse(value.toStringAsFixed(digits));
}

/// Use case for calculating balances in a group
class CalculateBalances {
  /// Calculate balances for all members in a group
  /// Returns a map of userId -> balance (positive = owed, negative = owes)
  ///
  /// [currency] drives the rounding of the results: XOF/XAF amounts are
  /// rounded to whole units, other currencies to 2 decimals.
  Map<String, double> calculateGroupBalances({
    required List<ExpenseEntity> expenses,
    required List<SettlementEntity> settlements,
    required List<String> memberIds,
    String currency = 'EUR',
  }) {
    // Initialize balances to 0 for all members
    final balances = {for (var id in memberIds) id: 0.0};

    // Process each expense
    for (final expense in expenses) {
      if (expense.isDeleted) continue;

      // The payer gets credited the full amount
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.amount;

      // Each participant owes their share
      for (final split in expense.splits) {
        balances[split.userId] =
            (balances[split.userId] ?? 0) - split.amount;
      }
    }

    // Process confirmed settlements
    for (final settlement in settlements) {
      if (settlement.status != SettlementStatus.confirmed) continue;

      // The person who paid sees their balance increase (less debt)
      balances[settlement.fromUserId] =
          (balances[settlement.fromUserId] ?? 0) + settlement.amount;

      // The person who received sees their balance decrease (less to receive)
      balances[settlement.toUserId] =
          (balances[settlement.toUserId] ?? 0) - settlement.amount;
    }

    // Round according to the currency's minor unit
    return balances.map((key, value) =>
        MapEntry(key, _roundForCurrency(value, currency)));
  }

  /// Calculate individual debts (who owes what to whom)
  /// Uses a greedy algorithm to minimize the number of transactions
  List<DebtEntity> calculateDebts({
    required Map<String, double> balances,
    String? groupId,
    String currency = 'EUR',
  }) {
    final debts = <DebtEntity>[];

    // Separate creditors (positive balance) and debtors (negative balance)
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    for (final entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors[entry.key] = entry.value;
      } else if (entry.value < -0.01) {
        debtors[entry.key] = -entry.value; // Convert to positive
      }
    }

    // Greedy algorithm to simplify debts
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      // Find the largest creditor
      final maxCreditor = creditors.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // Find the largest debtor
      final maxDebtor = debtors.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // Amount to transfer
      final amount = maxCreditor.value < maxDebtor.value
          ? maxCreditor.value
          : maxDebtor.value;

      // Create the debt
      if (amount > 0.01) {
        debts.add(DebtEntity(
          fromUserId: maxDebtor.key,
          toUserId: maxCreditor.key,
          amount: _roundForCurrency(amount, currency),
          groupId: groupId,
        ));
      }

      // Update amounts
      creditors[maxCreditor.key] = maxCreditor.value - amount;
      debtors[maxDebtor.key] = maxDebtor.value - amount;

      // Remove if balance is zero
      if (creditors[maxCreditor.key]! < 0.01) {
        creditors.remove(maxCreditor.key);
      }
      if (debtors[maxDebtor.key]! < 0.01) {
        debtors.remove(maxDebtor.key);
      }
    }

    return debts;
  }

  /// Calculate the total balance for a user across all groups
  BalanceEntity calculateUserTotalBalance({
    required String userId,
    required Map<String, Map<String, double>> groupBalances, // groupId -> (userId -> balance)
    required Map<String, String> groupNames, // groupId -> name
  }) {
    double totalBalance = 0;
    final balanceByUser = <String, double>{};
    final balanceByGroup = <String, double>{};

    for (final groupEntry in groupBalances.entries) {
      final groupId = groupEntry.key;
      final balances = groupEntry.value;

      // User's balance in this group
      final userBalance = balances[userId] ?? 0;
      if (userBalance.abs() > 0.01) {
        balanceByGroup[groupId] = userBalance;
        totalBalance += userBalance;
      }

      // Calculate balance with each other user
      for (final entry in balances.entries) {
        if (entry.key == userId) continue;

        final otherUserBalance = entry.value;
        // If user has positive balance and other has negative, other owes user
        // This is a simplification; full implementation would track debts
        balanceByUser[entry.key] =
            (balanceByUser[entry.key] ?? 0) + (userBalance > 0 && otherUserBalance < 0
                ? -otherUserBalance.clamp(0, userBalance)
                : 0);
      }
    }

    return BalanceEntity(
      userId: userId,
      totalBalance: double.parse(totalBalance.toStringAsFixed(2)),
      balanceByUser: balanceByUser,
      balanceByGroup: balanceByGroup,
    );
  }
}

/// Helper class for split calculations
class SplitCalculator {
  /// Calculate equal split amounts
  ///
  /// Rounding is currency-aware: XOF/XAF splits are whole units, other
  /// currencies use 2 decimals. Any rounding remainder goes to the first
  /// participant so the splits always sum exactly to [totalAmount].
  static List<ExpenseSplit> calculateEqualSplit({
    required double totalAmount,
    required List<String> participantIds,
    String currency = 'EUR',
  }) {
    if (participantIds.isEmpty) return [];

    final digits = CurrencyFormat.decimalDigits(currency);
    final amountPerPerson = totalAmount / participantIds.length;
    final roundedAmount = double.parse(amountPerPerson.toStringAsFixed(digits));

    // Handle rounding: give the remainder to the first person
    final remainder = double.parse(
      (totalAmount - (roundedAmount * participantIds.length))
          .toStringAsFixed(digits),
    );

    final firstAmount =
        double.parse((roundedAmount + remainder).toStringAsFixed(digits));

    return participantIds.asMap().entries.map((entry) {
      final index = entry.key;
      final userId = entry.value;
      final amount = index == 0 ? firstAmount : roundedAmount;

      return ExpenseSplit(
        userId: userId,
        amount: amount,
      );
    }).toList();
  }

  /// Calculate percentage-based split amounts
  ///
  /// Rounding is currency-aware (whole units for XOF/XAF). The rounding
  /// remainder is assigned to the first participant so the splits sum
  /// exactly to the amount represented by the percentages.
  static List<ExpenseSplit> calculatePercentageSplit({
    required double totalAmount,
    required Map<String, double> percentages, // userId -> percentage (0-100)
    String currency = 'EUR',
  }) {
    final digits = CurrencyFormat.decimalDigits(currency);
    final splits = percentages.entries.map((entry) {
      final amount = totalAmount * (entry.value / 100);
      return ExpenseSplit(
        userId: entry.key,
        amount: double.parse(amount.toStringAsFixed(digits)),
        percentage: entry.value,
      );
    }).toList();

    if (splits.isEmpty) return splits;

    // Give the rounding remainder to the first participant so the splits
    // keep summing exactly to the intended total.
    final totalPercent =
        percentages.values.fold<double>(0, (sum, p) => sum + p);
    final target = double.parse(
        (totalAmount * (totalPercent / 100)).toStringAsFixed(digits));
    final sum = splits.fold<double>(0, (s, split) => s + split.amount);
    final remainder = double.parse((target - sum).toStringAsFixed(digits));
    if (remainder != 0) {
      final first = splits.first;
      splits[0] = ExpenseSplit(
        userId: first.userId,
        amount: double.parse(
            (first.amount + remainder).toStringAsFixed(digits)),
        percentage: first.percentage,
      );
    }

    return splits;
  }

  /// Validate that splits add up to total amount
  static bool validateSplits({
    required double totalAmount,
    required List<ExpenseSplit> splits,
    double tolerance = 0.01,
  }) {
    final splitTotal = splits.fold<double>(
      0,
      (sum, split) => sum + split.amount,
    );
    return (splitTotal - totalAmount).abs() <= tolerance;
  }
}
