import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/balances/domain/usecases/calculate_balances.dart';
import 'package:leguejuste/features/expenses/domain/entities/expense_entity.dart';
import 'package:leguejuste/features/settlements/domain/entities/settlement_entity.dart';

// Helper to create an ExpenseEntity with minimal boilerplate
ExpenseEntity makeExpense({
  String id = 'e1',
  String groupId = 'g1',
  String description = 'Test',
  required double amount,
  required String paidBy,
  required List<ExpenseSplit> splits,
  bool isDeleted = false,
}) {
  final now = DateTime(2026, 1, 1);
  return ExpenseEntity(
    id: id,
    groupId: groupId,
    description: description,
    amount: amount,
    paidBy: paidBy,
    createdBy: paidBy,
    createdAt: now,
    updatedAt: now,
    date: now,
    splitType: SplitType.equal,
    splits: splits,
    isDeleted: isDeleted,
  );
}

// Helper to create a confirmed SettlementEntity
SettlementEntity makeSettlement({
  String id = 's1',
  String groupId = 'g1',
  required String fromUserId,
  required String toUserId,
  required double amount,
  SettlementStatus status = SettlementStatus.confirmed,
}) {
  return SettlementEntity(
    id: id,
    groupId: groupId,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amount: amount,
    createdAt: DateTime(2026, 1, 1),
    status: status,
  );
}

void main() {
  late CalculateBalances calculator;

  setUp(() {
    calculator = CalculateBalances();
  });

  // ---------------------------------------------------------------------------
  // calculateGroupBalances
  // ---------------------------------------------------------------------------
  group('calculateGroupBalances', () {
    test('no expenses and no settlements returns all balances at 0', () {
      final result = calculator.calculateGroupBalances(
        expenses: [],
        settlements: [],
        memberIds: ['A', 'B', 'C'],
      );

      expect(result['A'], 0.0);
      expect(result['B'], 0.0);
      expect(result['C'], 0.0);
    });

    test('1 expense, 2 members, equal split', () {
      // A pays 100, split equally between A and B (50 each)
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [],
        memberIds: ['A', 'B'],
      );

      // A: +100 (paid) - 50 (share) = +50
      expect(result['A'], 50.0);
      // B: -50 (share)
      expect(result['B'], -50.0);
    });

    test('multiple expenses accumulate correctly', () {
      // Expense 1: A pays 100, split A=50, B=50
      final e1 = makeExpense(
        id: 'e1',
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      // Expense 2: B pays 60, split A=30, B=30
      final e2 = makeExpense(
        id: 'e2',
        amount: 60,
        paidBy: 'B',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 30),
          const ExpenseSplit(userId: 'B', amount: 30),
        ],
      );

      final result = calculator.calculateGroupBalances(
        expenses: [e1, e2],
        settlements: [],
        memberIds: ['A', 'B'],
      );

      // A: +100 - 50 - 30 = +20
      expect(result['A'], 20.0);
      // B: +60 - 50 - 30 = -20
      expect(result['B'], -20.0);
    });

    test('settlements adjust balances', () {
      // A pays 100, split 50/50
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      // B settles 30 towards A
      final settlement = makeSettlement(
        fromUserId: 'B',
        toUserId: 'A',
        amount: 30,
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [settlement],
        memberIds: ['A', 'B'],
      );

      // A: +100 - 50 - 30 (received settlement) = +20
      expect(result['A'], 20.0);
      // B: -50 + 30 (paid settlement) = -20
      expect(result['B'], -20.0);
    });

    test('pending settlements are ignored', () {
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      final settlement = makeSettlement(
        fromUserId: 'B',
        toUserId: 'A',
        amount: 30,
        status: SettlementStatus.pending,
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [settlement],
        memberIds: ['A', 'B'],
      );

      // Settlement is pending, so ignored
      expect(result['A'], 50.0);
      expect(result['B'], -50.0);
    });

    test('deleted expenses are ignored', () {
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
        isDeleted: true,
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [],
        memberIds: ['A', 'B'],
      );

      expect(result['A'], 0.0);
      expect(result['B'], 0.0);
    });

    test('member with no involvement has balance 0', () {
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [],
        memberIds: ['A', 'B', 'C'],
      );

      expect(result['C'], 0.0);
    });

    test('handles decimal amounts with rounding', () {
      // 100 split among 3: 33.34, 33.33, 33.33
      final expense = makeExpense(
        amount: 100,
        paidBy: 'A',
        splits: [
          const ExpenseSplit(userId: 'A', amount: 33.34),
          const ExpenseSplit(userId: 'B', amount: 33.33),
          const ExpenseSplit(userId: 'C', amount: 33.33),
        ],
      );

      final result = calculator.calculateGroupBalances(
        expenses: [expense],
        settlements: [],
        memberIds: ['A', 'B', 'C'],
      );

      // A: +100 - 33.34 = +66.66
      expect(result['A'], 66.66);
      expect(result['B'], -33.33);
      expect(result['C'], -33.33);
    });
  });

  // ---------------------------------------------------------------------------
  // calculateDebts (greedy algorithm)
  // ---------------------------------------------------------------------------
  group('calculateDebts', () {
    test('all balances zero returns no debts', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 0.0, 'B': 0.0, 'C': 0.0},
      );

      expect(debts, isEmpty);
    });

    test('balances within threshold (0.01) returns no debts', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 0.005, 'B': -0.005},
      );

      expect(debts, isEmpty);
    });

    test('1 debtor, 1 creditor produces 1 debt', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 50.0, 'B': -50.0},
      );

      expect(debts.length, 1);
      expect(debts[0].fromUserId, 'B');
      expect(debts[0].toUserId, 'A');
      expect(debts[0].amount, 50.0);
    });

    test('3 members: A=+10, B=-4, C=-6', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 10.0, 'B': -4.0, 'C': -6.0},
      );

      // Total debts should sum to 10
      final totalDebtAmount =
          debts.fold<double>(0, (sum, d) => sum + d.amount);
      expect(totalDebtAmount, 10.0);

      // All debts should be to A (the only creditor)
      for (final debt in debts) {
        expect(debt.toUserId, 'A');
      }

      // Both B and C should appear as debtors
      final debtorIds = debts.map((d) => d.fromUserId).toSet();
      expect(debtorIds, containsAll(['B', 'C']));
    });

    test('3 members: greedy picks largest first', () {
      // A=+10, B=-6, C=-4
      // Greedy: largest debtor B pays largest creditor A: min(10,6)=6
      //   A becomes +4, C=-4
      //   Then C pays A: 4
      final debts = calculator.calculateDebts(
        balances: {'A': 10.0, 'B': -6.0, 'C': -4.0},
      );

      expect(debts.length, 2);
      // First debt: B -> A for 6
      expect(debts[0].fromUserId, 'B');
      expect(debts[0].toUserId, 'A');
      expect(debts[0].amount, 6.0);
      // Second debt: C -> A for 4
      expect(debts[1].fromUserId, 'C');
      expect(debts[1].toUserId, 'A');
      expect(debts[1].amount, 4.0);
    });

    test('multiple creditors and debtors', () {
      // A=+30, B=+20, C=-25, D=-25
      final debts = calculator.calculateDebts(
        balances: {'A': 30.0, 'B': 20.0, 'C': -25.0, 'D': -25.0},
      );

      // Total credits = 50, total debts = 50
      final totalDebtAmount =
          debts.fold<double>(0, (sum, d) => sum + d.amount);
      expect(totalDebtAmount, closeTo(50.0, 0.01));

      // Each debt amount should be > 0.01
      for (final debt in debts) {
        expect(debt.amount, greaterThan(0.01));
      }
    });

    test('decimal amounts are handled', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 33.33, 'B': -16.67, 'C': -16.66},
      );

      final totalDebtAmount =
          debts.fold<double>(0, (sum, d) => sum + d.amount);
      expect(totalDebtAmount, closeTo(33.33, 0.02));
    });

    test('groupId is passed through to debt entities', () {
      final debts = calculator.calculateDebts(
        balances: {'A': 10.0, 'B': -10.0},
        groupId: 'group123',
      );

      expect(debts[0].groupId, 'group123');
    });
  });

  // ---------------------------------------------------------------------------
  // calculateUserTotalBalance
  // ---------------------------------------------------------------------------
  group('calculateUserTotalBalance', () {
    test('single group with positive balance', () {
      final result = calculator.calculateUserTotalBalance(
        userId: 'A',
        groupBalances: {
          'g1': {'A': 50.0, 'B': -50.0},
        },
        groupNames: {'g1': 'Trip'},
      );

      expect(result.userId, 'A');
      expect(result.totalBalance, 50.0);
      expect(result.isOwed, true);
      expect(result.owes, false);
      expect(result.balanceByGroup['g1'], 50.0);
    });

    test('multiple groups accumulate total balance', () {
      final result = calculator.calculateUserTotalBalance(
        userId: 'A',
        groupBalances: {
          'g1': {'A': 30.0, 'B': -30.0},
          'g2': {'A': -10.0, 'C': 10.0},
        },
        groupNames: {'g1': 'Trip', 'g2': 'Rent'},
      );

      // 30 + (-10) = 20
      expect(result.totalBalance, 20.0);
      expect(result.balanceByGroup['g1'], 30.0);
      expect(result.balanceByGroup['g2'], -10.0);
    });

    test('user not present in group balances returns 0 for that group', () {
      final result = calculator.calculateUserTotalBalance(
        userId: 'A',
        groupBalances: {
          'g1': {'B': 10.0, 'C': -10.0},
        },
        groupNames: {'g1': 'Trip'},
      );

      expect(result.totalBalance, 0.0);
      expect(result.isSettled, true);
      // Group should not appear in balanceByGroup (balance < 0.01 threshold)
      expect(result.balanceByGroup.containsKey('g1'), false);
    });

    test('no groups returns zero balance', () {
      final result = calculator.calculateUserTotalBalance(
        userId: 'A',
        groupBalances: {},
        groupNames: {},
      );

      expect(result.totalBalance, 0.0);
      expect(result.isSettled, true);
      expect(result.balanceByGroup, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // SplitCalculator.calculateEqualSplit
  // ---------------------------------------------------------------------------
  group('SplitCalculator.calculateEqualSplit', () {
    test('exact division: 100 / 4 = 25 each', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 100,
        participantIds: ['A', 'B', 'C', 'D'],
      );

      expect(splits.length, 4);
      for (final split in splits) {
        expect(split.amount, 25.0);
      }

      // Verify total
      final total = splits.fold<double>(0, (sum, s) => sum + s.amount);
      expect(total, 100.0);
    });

    test('remainder: 100 / 3 - no lost cents', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 100,
        participantIds: ['A', 'B', 'C'],
      );

      expect(splits.length, 3);

      // Total must equal exactly 100
      final total = splits.fold<double>(0, (sum, s) => sum + s.amount);
      expect(total, closeTo(100.0, 0.01));

      // First person gets the remainder
      // 100/3 = 33.333... rounded to 33.33
      // remainder = 100 - 33.33*3 = 100 - 99.99 = 0.01
      // So first = 33.33 + 0.01 = 33.34, others = 33.33
      expect(splits[0].amount, closeTo(33.34, 0.01));
      expect(splits[1].amount, closeTo(33.33, 0.01));
      expect(splits[2].amount, closeTo(33.33, 0.01));
    });

    test('remainder: 10 / 3 - no lost cents', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 10,
        participantIds: ['A', 'B', 'C'],
      );

      final total = splits.fold<double>(0, (sum, s) => sum + s.amount);
      expect(total, closeTo(10.0, 0.01));
    });

    test('single participant gets full amount', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 100,
        participantIds: ['A'],
      );

      expect(splits.length, 1);
      expect(splits[0].userId, 'A');
      expect(splits[0].amount, 100.0);
    });

    test('amount 0 gives all 0', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 0,
        participantIds: ['A', 'B', 'C'],
      );

      expect(splits.length, 3);
      for (final split in splits) {
        expect(split.amount, 0.0);
      }
    });

    test('empty participants returns empty list', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 100,
        participantIds: [],
      );

      expect(splits, isEmpty);
    });

    test('userIds are correctly assigned', () {
      final splits = SplitCalculator.calculateEqualSplit(
        totalAmount: 100,
        participantIds: ['Alice', 'Bob'],
      );

      expect(splits[0].userId, 'Alice');
      expect(splits[1].userId, 'Bob');
    });
  });

  // ---------------------------------------------------------------------------
  // SplitCalculator.calculatePercentageSplit
  // ---------------------------------------------------------------------------
  group('SplitCalculator.calculatePercentageSplit', () {
    test('50/50 on 100', () {
      final splits = SplitCalculator.calculatePercentageSplit(
        totalAmount: 100,
        percentages: {'A': 50, 'B': 50},
      );

      expect(splits.length, 2);
      final splitMap = {for (var s in splits) s.userId: s};
      expect(splitMap['A']!.amount, 50.0);
      expect(splitMap['B']!.amount, 50.0);
    });

    test('33.33/33.33/33.34 on 100', () {
      final splits = SplitCalculator.calculatePercentageSplit(
        totalAmount: 100,
        percentages: {'A': 33.33, 'B': 33.33, 'C': 33.34},
      );

      final splitMap = {for (var s in splits) s.userId: s};
      expect(splitMap['A']!.amount, 33.33);
      expect(splitMap['B']!.amount, 33.33);
      expect(splitMap['C']!.amount, 33.34);

      final total = splits.fold<double>(0, (sum, s) => sum + s.amount);
      expect(total, 100.0);
    });

    test('percentage is stored on the split', () {
      final splits = SplitCalculator.calculatePercentageSplit(
        totalAmount: 200,
        percentages: {'A': 70, 'B': 30},
      );

      final splitMap = {for (var s in splits) s.userId: s};
      expect(splitMap['A']!.percentage, 70);
      expect(splitMap['B']!.percentage, 30);
      expect(splitMap['A']!.amount, 140.0);
      expect(splitMap['B']!.amount, 60.0);
    });

    test('0% gives amount 0', () {
      final splits = SplitCalculator.calculatePercentageSplit(
        totalAmount: 100,
        percentages: {'A': 100, 'B': 0},
      );

      final splitMap = {for (var s in splits) s.userId: s};
      expect(splitMap['A']!.amount, 100.0);
      expect(splitMap['B']!.amount, 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // SplitCalculator.validateSplits
  // ---------------------------------------------------------------------------
  group('SplitCalculator.validateSplits', () {
    test('valid splits summing to total', () {
      final result = SplitCalculator.validateSplits(
        totalAmount: 100,
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      expect(result, true);
    });

    test('invalid splits not summing to total', () {
      final result = SplitCalculator.validateSplits(
        totalAmount: 100,
        splits: [
          const ExpenseSplit(userId: 'A', amount: 40),
          const ExpenseSplit(userId: 'B', amount: 50),
        ],
      );

      expect(result, false);
    });

    test('within tolerance of 0.01 is valid', () {
      // 50.004 + 50.004 = 100.008, diff from 100 = 0.008 which is < 0.01
      final result = SplitCalculator.validateSplits(
        totalAmount: 100,
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50.004),
          const ExpenseSplit(userId: 'B', amount: 50.004),
        ],
      );

      expect(result, true);
    });

    test('just outside tolerance is invalid', () {
      final result = SplitCalculator.validateSplits(
        totalAmount: 100,
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 49.98),
        ],
      );

      expect(result, false);
    });

    test('custom tolerance', () {
      final result = SplitCalculator.validateSplits(
        totalAmount: 100,
        splits: [
          const ExpenseSplit(userId: 'A', amount: 50),
          const ExpenseSplit(userId: 'B', amount: 49.5),
        ],
        tolerance: 1.0,
      );

      expect(result, true);
    });

    test('empty splits with total 0 is valid', () {
      final result = SplitCalculator.validateSplits(
        totalAmount: 0,
        splits: [],
      );

      expect(result, true);
    });
  });
}
