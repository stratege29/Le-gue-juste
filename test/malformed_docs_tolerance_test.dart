import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/constants/firebase_constants.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/expenses/domain/entities/expense_entity.dart';
import 'package:leguejuste/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:leguejuste/features/groups/presentation/providers/groups_provider.dart';
import 'package:leguejuste/features/settlements/presentation/providers/settlements_provider.dart';

/// A single malformed Firestore doc must be SKIPPED, never permanently
/// error the whole stream for every group member.
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProviderContainer container;

  const groupId = 'g1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fakeFirestore),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  CollectionReference<Map<String, dynamic>> expensesRef() => fakeFirestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .collection(FirebaseConstants.expensesSubcollection);

  CollectionReference<Map<String, dynamic>> settlementsRef() => fakeFirestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .collection(FirebaseConstants.settlementsSubcollection);

  Future<void> createGroupDoc({String currency = 'XOF'}) {
    return fakeFirestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .set({
      'name': 'Test Group',
      'currency': currency,
      'createdBy': 'A',
      'memberIds': ['A', 'B'],
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Map<String, dynamic> validExpense({
    required double amount,
    String paidBy = 'A',
  }) {
    final now = Timestamp.now();
    return {
      'description': 'Valid',
      'amount': amount,
      'currency': 'XOF',
      'paidBy': paidBy,
      'createdBy': paidBy,
      'createdAt': now,
      'updatedAt': now,
      'date': now,
      'splitType': 'equal',
      'splits': {
        'A': {'amount': amount / 2, 'percentage': null, 'isPaid': false},
        'B': {'amount': amount / 2, 'percentage': null, 'isPaid': false},
      },
      'isDeleted': false,
    };
  }

  group('groupExpensesProvider tolerance', () {
    test('a doc missing amount is skipped, not fatal for the stream',
        () async {
      await expensesRef().doc('ok').set(validExpense(amount: 100));

      // Malformed: no amount.
      await expensesRef().doc('bad').set({
        'description': 'Broken',
        'paidBy': 'A',
        'date': Timestamp.now(),
        'isDeleted': false,
      });

      final expenses =
          await container.read(groupExpensesProvider(groupId).future);

      expect(expenses.length, 1);
      expect(expenses.single.id, 'ok');
    });

    test('unknown splitType falls back to equal instead of crashing',
        () async {
      final data = validExpense(amount: 100);
      data['splitType'] = 'legacy-weird-value';
      await expensesRef().doc('e1').set(data);

      final expenses =
          await container.read(groupExpensesProvider(groupId).future);

      expect(expenses.length, 1);
      expect(expenses.single.splitType, SplitType.equal);
    });

    test('missing timestamps and description get safe defaults', () async {
      await expensesRef().doc('e1').set({
        'amount': 50,
        'paidBy': 'A',
        'date': Timestamp.now(),
        'isDeleted': false,
        'splits': {'B': 50},
      });

      final expenses =
          await container.read(groupExpensesProvider(groupId).future);

      expect(expenses.length, 1);
      expect(expenses.single.description, '');
      expect(expenses.single.splits.single.amount, 50.0);
    });
  });

  group('groupSettlementsProvider tolerance', () {
    test('a doc missing fromUserId is skipped, not fatal', () async {
      await settlementsRef().doc('ok').set({
        'fromUserId': 'B',
        'toUserId': 'A',
        'amount': 25,
        'createdAt': Timestamp.now(),
        'status': 'confirmed',
      });
      await settlementsRef().doc('bad').set({
        'toUserId': 'A',
        'amount': 25,
        'createdAt': Timestamp.now(),
      });

      final settlements =
          await container.read(groupSettlementsProvider(groupId).future);

      expect(settlements.length, 1);
      expect(settlements.single.id, 'ok');
    });
  });

  group('groupBalancesProvider with malformed docs', () {
    test('balances are computed from the valid docs only', () async {
      await createGroupDoc();
      await expensesRef().doc('ok').set(validExpense(amount: 100));
      await expensesRef().doc('bad').set({
        'description': 'Broken',
        'paidBy': 'A',
        'date': Timestamp.now(),
        'isDeleted': false,
      });

      // Wait for the underlying streams to emit.
      await container.read(groupExpensesProvider(groupId).future);
      await container.read(groupSettlementsProvider(groupId).future);
      await container.read(groupProvider(groupId).future);

      final balancesAsync = container.read(groupBalancesProvider(groupId));

      expect(balancesAsync.hasError, false);
      final balances = balancesAsync.valueOrNull;
      expect(balances, isNotNull);
      // A paid 100, own share 50 -> +50; B owes 50.
      expect(balances!['A'], 50.0);
      expect(balances['B'], -50.0);
    });
  });
}
