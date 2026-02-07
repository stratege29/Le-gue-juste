import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/settlement_entity.dart';

export '../../domain/entities/settlement_entity.dart';

/// Stream of settlements for a group
final groupSettlementsProvider =
    StreamProvider.family<List<SettlementEntity>, String>((ref, groupId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .collection('settlements')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final statusStr = data['status'] as String? ?? 'confirmed';
            return SettlementEntity(
              id: doc.id,
              groupId: groupId,
              fromUserId: data['fromUserId'] as String,
              toUserId: data['toUserId'] as String,
              amount: (data['amount'] as num).toDouble(),
              currency: data['currency'] as String? ?? 'EUR',
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              confirmedAt: data['confirmedAt'] != null
                  ? (data['confirmedAt'] as Timestamp).toDate()
                  : null,
              status: statusStr == 'pending'
                  ? SettlementStatus.pending
                  : SettlementStatus.confirmed,
              note: data['note'] as String?,
            );
          }).toList());
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
    String currency = 'EUR',
    String? note,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecte', StackTrace.current);
        return false;
      }

      final now = DateTime.now();
      final settlementId = const Uuid().v4();

      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .set({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
        'currency': currency,
        'note': note,
        'createdBy': currentUser.uid,
        'createdAt': Timestamp.fromDate(now),
        'confirmedAt': Timestamp.fromDate(now),
        'status': 'confirmed',
      });

      // Update group's updatedAt
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .update({
        FirebaseConstants.updatedAt: Timestamp.now(),
      });

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
          .collection('settlements')
          .doc(settlementId)
          .delete();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
