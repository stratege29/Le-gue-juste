import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';

/// Utility class to seed test data for development
class TestDataSeeder {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TestDataSeeder(this._firestore, this._auth);

  /// Creates two fictional friends and adds them to groups with the current user
  /// Creates scenarios where user owes money AND is owed money
  Future<String?> seedTestData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Create fictional users
      final aliceId = 'test_alice_$ts';
      final bobId = 'test_bob_$ts';
      final charlieId = 'test_charlie_$ts';

      final now = Timestamp.now();

      // Create Alice
      await _firestore.collection(FirebaseConstants.usersCollection).doc(aliceId).set({
        FirebaseConstants.displayName: 'Alice (Test)',
        FirebaseConstants.phoneNumber: '+33600000001',
        FirebaseConstants.qrCode: 'LGJ-ALICE-$ts',
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // Create Bob
      await _firestore.collection(FirebaseConstants.usersCollection).doc(bobId).set({
        FirebaseConstants.displayName: 'Bob (Test)',
        FirebaseConstants.phoneNumber: '+33600000002',
        FirebaseConstants.qrCode: 'LGJ-BOB-$ts',
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // Create Charlie
      await _firestore.collection(FirebaseConstants.usersCollection).doc(charlieId).set({
        FirebaseConstants.displayName: 'Charlie (Test)',
        FirebaseConstants.phoneNumber: '+33600000003',
        FirebaseConstants.qrCode: 'LGJ-CHARLIE-$ts',
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // ========== GROUP 1: Vacances Espagne ==========
      // User OWES money here (Alice paid for hotel, Bob paid for activities)
      final group1Ref = await _firestore.collection(FirebaseConstants.groupsCollection).add({
        FirebaseConstants.groupName: 'Vacances Espagne',
        FirebaseConstants.groupDescription: 'Voyage a Barcelone',
        FirebaseConstants.groupCreatedBy: currentUser.uid,
        FirebaseConstants.groupMemberIds: [currentUser.uid, aliceId, bobId],
        FirebaseConstants.groupCurrency: 'EUR',
        FirebaseConstants.groupSimplifyDebts: true,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      final expenses1Ref = group1Ref.collection(FirebaseConstants.expensesSubcollection);

      // Alice paid for hotel (big expense) - User owes Alice
      await expenses1Ref.add({
        FirebaseConstants.expenseDescription: 'Hotel Barcelone 3 nuits',
        FirebaseConstants.expenseAmount: 450.0,
        FirebaseConstants.expenseCurrency: 'EUR',
        FirebaseConstants.expensePaidBy: aliceId,
        FirebaseConstants.expenseCreatedBy: aliceId,
        FirebaseConstants.expenseDate: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
        FirebaseConstants.expenseCategory: 'travel',
        FirebaseConstants.expenseSplitType: 'equal',
        FirebaseConstants.expenseSplits: {
          currentUser.uid: {'amount': 150.0, 'percentage': null, 'isPaid': false},
          aliceId: {'amount': 150.0, 'percentage': null, 'isPaid': false},
          bobId: {'amount': 150.0, 'percentage': null, 'isPaid': false},
        },
        FirebaseConstants.expenseIsDeleted: false,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // Bob paid for Sagrada Familia tickets - User owes Bob
      await expenses1Ref.add({
        FirebaseConstants.expenseDescription: 'Billets Sagrada Familia',
        FirebaseConstants.expenseAmount: 78.0,
        FirebaseConstants.expenseCurrency: 'EUR',
        FirebaseConstants.expensePaidBy: bobId,
        FirebaseConstants.expenseCreatedBy: bobId,
        FirebaseConstants.expenseDate: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 4))),
        FirebaseConstants.expenseCategory: 'entertainment',
        FirebaseConstants.expenseSplitType: 'equal',
        FirebaseConstants.expenseSplits: {
          currentUser.uid: {'amount': 26.0, 'percentage': null, 'isPaid': false},
          aliceId: {'amount': 26.0, 'percentage': null, 'isPaid': false},
          bobId: {'amount': 26.0, 'percentage': null, 'isPaid': false},
        },
        FirebaseConstants.expenseIsDeleted: false,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // User paid for tapas (small expense)
      await expenses1Ref.add({
        FirebaseConstants.expenseDescription: 'Tapas Bar El Nacional',
        FirebaseConstants.expenseAmount: 60.0,
        FirebaseConstants.expenseCurrency: 'EUR',
        FirebaseConstants.expensePaidBy: currentUser.uid,
        FirebaseConstants.expenseCreatedBy: currentUser.uid,
        FirebaseConstants.expenseDate: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
        FirebaseConstants.expenseCategory: 'food',
        FirebaseConstants.expenseSplitType: 'equal',
        FirebaseConstants.expenseSplits: {
          currentUser.uid: {'amount': 20.0, 'percentage': null, 'isPaid': false},
          aliceId: {'amount': 20.0, 'percentage': null, 'isPaid': false},
          bobId: {'amount': 20.0, 'percentage': null, 'isPaid': false},
        },
        FirebaseConstants.expenseIsDeleted: false,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });
      // Group 1 balance: User paid 60, owes 150+26+20 = 196, net = -136 (OWES €136)

      // ========== GROUP 2: Coloc ==========
      // User is OWED money here (User paid rent and utilities)
      final group2Ref = await _firestore.collection(FirebaseConstants.groupsCollection).add({
        FirebaseConstants.groupName: 'Coloc Appartement',
        FirebaseConstants.groupDescription: 'Depenses colocation',
        FirebaseConstants.groupCreatedBy: currentUser.uid,
        FirebaseConstants.groupMemberIds: [currentUser.uid, charlieId],
        FirebaseConstants.groupCurrency: 'EUR',
        FirebaseConstants.groupSimplifyDebts: true,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      final expenses2Ref = group2Ref.collection(FirebaseConstants.expensesSubcollection);

      // User paid for internet - Charlie owes user
      await expenses2Ref.add({
        FirebaseConstants.expenseDescription: 'Abonnement Internet Free',
        FirebaseConstants.expenseAmount: 40.0,
        FirebaseConstants.expenseCurrency: 'EUR',
        FirebaseConstants.expensePaidBy: currentUser.uid,
        FirebaseConstants.expenseCreatedBy: currentUser.uid,
        FirebaseConstants.expenseDate: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10))),
        FirebaseConstants.expenseCategory: 'utilities',
        FirebaseConstants.expenseSplitType: 'equal',
        FirebaseConstants.expenseSplits: {
          currentUser.uid: {'amount': 20.0, 'percentage': null, 'isPaid': false},
          charlieId: {'amount': 20.0, 'percentage': null, 'isPaid': false},
        },
        FirebaseConstants.expenseIsDeleted: false,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });

      // User paid for electricity - Charlie owes user
      await expenses2Ref.add({
        FirebaseConstants.expenseDescription: 'Facture EDF Janvier',
        FirebaseConstants.expenseAmount: 86.0,
        FirebaseConstants.expenseCurrency: 'EUR',
        FirebaseConstants.expensePaidBy: currentUser.uid,
        FirebaseConstants.expenseCreatedBy: currentUser.uid,
        FirebaseConstants.expenseDate: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        FirebaseConstants.expenseCategory: 'utilities',
        FirebaseConstants.expenseSplitType: 'equal',
        FirebaseConstants.expenseSplits: {
          currentUser.uid: {'amount': 43.0, 'percentage': null, 'isPaid': false},
          charlieId: {'amount': 43.0, 'percentage': null, 'isPaid': false},
        },
        FirebaseConstants.expenseIsDeleted: false,
        FirebaseConstants.createdAt: now,
        FirebaseConstants.updatedAt: now,
      });
      // Group 2 balance: User paid 126, owes 63, net = +63 (OWED €63)

      // TOTAL: User owes €136, is owed €63 = Net -€73

      debugPrint('Test data created successfully!');
      debugPrint('Group 1 (Vacances Espagne): User owes ~€136');
      debugPrint('Group 2 (Coloc): User is owed ~€63');

      return group1Ref.id;
    } catch (e) {
      debugPrint('Error seeding test data: $e');
      return null;
    }
  }

  /// Deletes all test data (users and groups with "Test" in name)
  Future<void> cleanupTestData() async {
    try {
      // Delete test users (those with "(Test)" in name)
      final allUsers = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .get();

      for (final doc in allUsers.docs) {
        final name = doc.data()[FirebaseConstants.displayName]?.toString() ?? '';
        if (name.contains('(Test)')) {
          await doc.reference.delete();
          debugPrint('Deleted test user: $name');
        }
      }

      // Delete test groups
      final testGroupNames = ['Vacances Test', 'Vacances Espagne', 'Coloc Appartement'];

      for (final groupName in testGroupNames) {
        final testGroups = await _firestore
            .collection(FirebaseConstants.groupsCollection)
            .where(FirebaseConstants.groupName, isEqualTo: groupName)
            .get();

        for (final doc in testGroups.docs) {
          // Delete expenses first
          final expenses = await doc.reference.collection(FirebaseConstants.expensesSubcollection).get();
          for (final expense in expenses.docs) {
            await expense.reference.delete();
          }
          // Delete settlements
          final settlements = await doc.reference.collection('settlements').get();
          for (final settlement in settlements.docs) {
            await settlement.reference.delete();
          }
          await doc.reference.delete();
          debugPrint('Deleted test group: $groupName');
        }
      }

      debugPrint('Test data cleanup complete!');
    } catch (e) {
      debugPrint('Error cleaning up test data: $e');
    }
  }
}
