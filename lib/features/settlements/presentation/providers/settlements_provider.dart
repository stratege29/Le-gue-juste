import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/settlement_entity.dart';

export '../../domain/entities/settlement_entity.dart';

/// Parses one settlement doc tolerantly.
///
/// Returns null for irrecoverably malformed docs (missing user ids or
/// amount) so a single bad doc is skipped instead of permanently erroring
/// the settlements stream for every group member.
SettlementEntity? _settlementFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  String groupId,
) {
  try {
    final data = doc.data();
    final fromUserId = data['fromUserId'] as String?;
    final toUserId = data['toUserId'] as String?;
    final amount = (data['amount'] as num?)?.toDouble();
    if (fromUserId == null || toUserId == null || amount == null) {
      if (kDebugMode) {
        debugPrint('Skipping malformed settlement doc ${doc.id}: '
            'missing fromUserId/toUserId/amount');
      }
      return null;
    }

    final statusStr = data['status'] as String? ?? 'confirmed';
    final paymentMethodStr = data['paymentMethod'] as String? ?? 'manual';
    return SettlementEntity(
      id: doc.id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      currency: data['currency'] as String? ?? 'XOF',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      status: statusStr == 'pending'
          ? SettlementStatus.pending
          : SettlementStatus.confirmed,
      note: data['note'] as String?,
      paymentMethod: paymentMethodStr == 'wave'
          ? PaymentMethod.wave
          : PaymentMethod.manual,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Skipping malformed settlement doc ${doc.id}: $e');
    }
    return null;
  }
}

/// Stream of settlements for a group
final groupSettlementsProvider =
    StreamProvider.family<List<SettlementEntity>, String>((ref, groupId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .collection(FirebaseConstants.settlementsSubcollection)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => _settlementFromDoc(doc, groupId))
          .whereType<SettlementEntity>()
          .toList());
});

/// Settlements notifier for CRUD operations
final settlementsNotifierProvider =
    StateNotifierProvider<SettlementsNotifier, AsyncValue<void>>((ref) {
  return SettlementsNotifier(
    ref.watch(firestoreProvider),
    ref,
  );
});

class SettlementsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SettlementsNotifier(this._firestore, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> createSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String currency = 'XOF',
    String? note,
    PaymentMethod paymentMethod = PaymentMethod.manual,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecté', StackTrace.current);
        return false;
      }

      final now = DateTime.now();
      final settlementId = const Uuid().v4();

      // Batch write: settlement doc + group updatedAt atomically
      final batch = _firestore.batch();

      final settlementRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc(settlementId);
      batch.set(settlementRef, {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
        'currency': currency,
        'note': note,
        'createdBy': currentUser.uid,
        'createdAt': Timestamp.fromDate(now),
        'confirmedAt': Timestamp.fromDate(now),
        'status': 'confirmed',
        'paymentMethod': paymentMethod.name,
      });

      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId);
      batch.update(groupRef, {
        FirebaseConstants.updatedAt: Timestamp.fromDate(now),
      });

      await batch.commit();

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> deleteSettlement({
    required String groupId,
    required String settlementId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.settlementsSubcollection)
          .doc(settlementId)
          .delete();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
