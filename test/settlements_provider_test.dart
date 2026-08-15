import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leguejuste/core/constants/firebase_constants.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/settlements/domain/entities/settlement_entity.dart';
import 'package:leguejuste/features/settlements/presentation/providers/settlements_provider.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'test-user-id';
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProviderContainer container;
  late MockUser mockUser;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser();

    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fakeFirestore),
        authStateProvider.overrideWith((_) => Stream.value(mockUser)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> waitForAuth() async {
    await container.read(authStateProvider.future);
  }

  /// Helper: create a group doc so batch.update doesn't fail
  Future<void> createGroup(String groupId) async {
    await fakeFirestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .set({
      'name': 'Test Group',
      'currency': 'XOF',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Helper: read settlement doc from Firestore
  Future<Map<String, dynamic>?> readSettlement(
      String groupId, String settlementId) async {
    final doc = await fakeFirestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .collection(FirebaseConstants.settlementsSubcollection)
        .doc(settlementId)
        .get();
    return doc.data();
  }

  /// Helper: list all settlements for a group
  Future<List<Map<String, dynamic>>> listSettlements(String groupId) async {
    final snapshot = await fakeFirestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .collection(FirebaseConstants.settlementsSubcollection)
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  group('SettlementsNotifier.createSettlement', () {
    test('creates settlement with default manual paymentMethod', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      final success = await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
      );

      expect(success, true);

      final settlements = await listSettlements('g1');
      expect(settlements, hasLength(1));
      expect(settlements.first['paymentMethod'], 'manual');
      expect(settlements.first['fromUserId'], 'alice');
      expect(settlements.first['toUserId'], 'bob');
      expect(settlements.first['amount'], 5000);
      expect(settlements.first['status'], 'confirmed');
    });

    test('creates settlement with wave paymentMethod', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      final success = await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 10000,
        paymentMethod: PaymentMethod.wave,
      );

      expect(success, true);

      final settlements = await listSettlements('g1');
      expect(settlements, hasLength(1));
      expect(settlements.first['paymentMethod'], 'wave');
    });

    test('creates settlement with explicit manual paymentMethod', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 3000,
        paymentMethod: PaymentMethod.manual,
      );

      final settlements = await listSettlements('g1');
      expect(settlements.first['paymentMethod'], 'manual');
    });

    test('stores note alongside paymentMethod', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 7500,
        note: 'Paiement Wave',
        paymentMethod: PaymentMethod.wave,
      );

      final settlements = await listSettlements('g1');
      expect(settlements.first['note'], 'Paiement Wave');
      expect(settlements.first['paymentMethod'], 'wave');
    });

    test('stores currency correctly', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        currency: 'EUR',
        paymentMethod: PaymentMethod.wave,
      );

      final settlements = await listSettlements('g1');
      expect(settlements.first['currency'], 'EUR');
    });

    test('sets status to confirmed', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        paymentMethod: PaymentMethod.wave,
      );

      final settlements = await listSettlements('g1');
      expect(settlements.first['status'], 'confirmed');
      expect(settlements.first['confirmedAt'], isNotNull);
    });

    test('records createdBy from auth user', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
      );

      final settlements = await listSettlements('g1');
      expect(settlements.first['createdBy'], 'test-user-id');
    });

    test('returns false when not authenticated', () async {
      // Override with no auth user
      final noAuthContainer = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          authStateProvider.overrideWith((_) => Stream.value(null)),
        ],
      );

      await noAuthContainer.read(authStateProvider.future);

      final notifier =
          noAuthContainer.read(settlementsNotifierProvider.notifier);
      final success = await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
      );

      expect(success, false);

      noAuthContainer.dispose();
    });

    test('creates multiple settlements with different payment methods',
        () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);

      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        paymentMethod: PaymentMethod.manual,
      );

      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'charlie',
        toUserId: 'bob',
        amount: 3000,
        paymentMethod: PaymentMethod.wave,
      );

      final settlements = await listSettlements('g1');
      expect(settlements, hasLength(2));

      final methods =
          settlements.map((s) => s['paymentMethod'] as String).toSet();
      expect(methods, containsAll(['manual', 'wave']));
    });

    test('updates group updatedAt timestamp', () async {
      await waitForAuth();
      await createGroup('g1');

      final beforeDoc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .get();
      final beforeUpdatedAt = beforeDoc.data()!['updatedAt'] as Timestamp;

      // Small delay to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        paymentMethod: PaymentMethod.wave,
      );

      final afterDoc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .get();
      final afterUpdatedAt = afterDoc.data()!['updatedAt'] as Timestamp;

      expect(afterUpdatedAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(beforeUpdatedAt.millisecondsSinceEpoch));
    });
  });

  group('SettlementsNotifier.deleteSettlement', () {
    test('deletes an existing settlement', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        paymentMethod: PaymentMethod.wave,
      );

      final settlements = await listSettlements('g1');
      expect(settlements, hasLength(1));

      final settlementId = settlements.first['id'] as String;
      await notifier.deleteSettlement(
        groupId: 'g1',
        settlementId: settlementId,
      );

      final afterDelete = await listSettlements('g1');
      expect(afterDelete, isEmpty);
    });
  });

  group('groupSettlementsProvider - paymentMethod parsing', () {
    test('reads wave paymentMethod from Firestore', () async {
      // Seed Firestore directly with a wave settlement
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s1')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'confirmedAt': Timestamp.now(),
        'status': 'confirmed',
        'paymentMethod': 'wave',
        'note': 'Wave payment',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements, hasLength(1));
      expect(settlements.first.paymentMethod, PaymentMethod.wave);
      expect(settlements.first.isWavePayment, true);
      expect(settlements.first.note, 'Wave payment');
    });

    test('reads manual paymentMethod from Firestore', () async {
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s1')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'confirmedAt': Timestamp.now(),
        'status': 'confirmed',
        'paymentMethod': 'manual',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements.first.paymentMethod, PaymentMethod.manual);
      expect(settlements.first.isWavePayment, false);
    });

    test('defaults to manual when paymentMethod field is missing (backward compatibility)',
        () async {
      // Simulate a legacy settlement without paymentMethod
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s-legacy')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 3000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'status': 'confirmed',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements, hasLength(1));
      expect(settlements.first.paymentMethod, PaymentMethod.manual);
      expect(settlements.first.isWavePayment, false);
    });

    test('defaults to manual for unknown paymentMethod string', () async {
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s1')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'status': 'confirmed',
        'paymentMethod': 'bitcoin',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements.first.paymentMethod, PaymentMethod.manual);
    });

    test('reads mixed payment methods in same group', () async {
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s-manual')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'status': 'confirmed',
        'paymentMethod': 'manual',
      });

      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s-wave')
          .set({
        'fromUserId': 'charlie',
        'toUserId': 'bob',
        'amount': 3000,
        'currency': 'XOF',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2)),
        'status': 'confirmed',
        'paymentMethod': 'wave',
      });

      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s-legacy')
          .set({
        'fromUserId': 'dave',
        'toUserId': 'bob',
        'amount': 1000,
        'currency': 'XOF',
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 28)),
        'status': 'confirmed',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements, hasLength(3));

      // Ordered by createdAt descending
      final methods = settlements.map((s) => s.paymentMethod).toList();
      expect(methods, [
        PaymentMethod.wave,   // 2026-03-02
        PaymentMethod.manual, // 2026-03-01
        PaymentMethod.manual, // 2026-02-28 (legacy, no field)
      ]);
    });

    test('reads all fields correctly from Firestore', () async {
      final createdAt = DateTime(2026, 3, 5, 10, 30);
      final confirmedAt = DateTime(2026, 3, 5, 10, 31);

      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s-full')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 7500,
        'currency': 'EUR',
        'createdAt': Timestamp.fromDate(createdAt),
        'confirmedAt': Timestamp.fromDate(confirmedAt),
        'status': 'pending',
        'note': 'Test note',
        'paymentMethod': 'wave',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);
      final s = settlements.first;

      expect(s.id, 's-full');
      expect(s.groupId, 'g1');
      expect(s.fromUserId, 'alice');
      expect(s.toUserId, 'bob');
      expect(s.amount, 7500);
      expect(s.currency, 'EUR');
      expect(s.createdAt, createdAt);
      expect(s.confirmedAt, confirmedAt);
      expect(s.status, SettlementStatus.pending);
      expect(s.note, 'Test note');
      expect(s.paymentMethod, PaymentMethod.wave);
    });

    test('handles null note gracefully', () async {
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s1')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'status': 'confirmed',
        'paymentMethod': 'wave',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements.first.note, isNull);
      expect(settlements.first.paymentMethod, PaymentMethod.wave);
    });

    test('handles null confirmedAt gracefully', () async {
      await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc('g1')
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc('s1')
          .set({
        'fromUserId': 'alice',
        'toUserId': 'bob',
        'amount': 5000,
        'currency': 'XOF',
        'createdAt': Timestamp.now(),
        'status': 'pending',
        'paymentMethod': 'wave',
      });

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements.first.confirmedAt, isNull);
      expect(settlements.first.isPending, true);
    });
  });

  group('End-to-end: create then read settlement', () {
    test('manual settlement round-trip', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        currency: 'XOF',
        note: 'Cash payment',
        paymentMethod: PaymentMethod.manual,
      );

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements, hasLength(1));
      final s = settlements.first;
      expect(s.fromUserId, 'alice');
      expect(s.toUserId, 'bob');
      expect(s.amount, 5000);
      expect(s.currency, 'XOF');
      expect(s.note, 'Cash payment');
      expect(s.paymentMethod, PaymentMethod.manual);
      expect(s.isWavePayment, false);
      expect(s.isConfirmed, true);
    });

    test('wave settlement round-trip', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 10000,
        currency: 'XOF',
        note: 'Paiement Wave',
        paymentMethod: PaymentMethod.wave,
      );

      final settlements =
          await container.read(groupSettlementsProvider('g1').future);

      expect(settlements, hasLength(1));
      final s = settlements.first;
      expect(s.fromUserId, 'alice');
      expect(s.toUserId, 'bob');
      expect(s.amount, 10000);
      expect(s.note, 'Paiement Wave');
      expect(s.paymentMethod, PaymentMethod.wave);
      expect(s.isWavePayment, true);
      expect(s.isConfirmed, true);
    });

    test('create and delete wave settlement', () async {
      await waitForAuth();
      await createGroup('g1');

      final notifier = container.read(settlementsNotifierProvider.notifier);
      await notifier.createSettlement(
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        paymentMethod: PaymentMethod.wave,
      );

      var settlements =
          await container.read(groupSettlementsProvider('g1').future);
      expect(settlements, hasLength(1));

      await notifier.deleteSettlement(
        groupId: 'g1',
        settlementId: settlements.first.id,
      );

      settlements =
          await container.read(groupSettlementsProvider('g1').future);
      expect(settlements, isEmpty);
    });
  });
}
