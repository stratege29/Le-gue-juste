import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../../data/models/group_model.dart';

/// Stream of user's groups
final userGroupsProvider = StreamProvider<List<GroupEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .where(FirebaseConstants.groupMemberIds, arrayContains: user.uid)
      .orderBy(FirebaseConstants.updatedAt, descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc).toEntity())
          .toList());
});

/// Single group by ID
final groupProvider = StreamProvider.family<GroupEntity?, String>((ref, groupId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return GroupModel.fromFirestore(doc).toEntity();
  });
});

/// Provider to get member names for a group
final groupMemberNamesProvider = FutureProvider.family<Map<String, String>, String>((ref, groupId) async {
  final firestore = ref.watch(firestoreProvider);
  final group = await firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId)
      .get();

  if (!group.exists) return {};

  final memberIds = List<String>.from(group.data()?['memberIds'] ?? []);
  final memberNames = <String, String>{};

  for (final memberId in memberIds) {
    final userDoc = await firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(memberId)
        .get();

    if (userDoc.exists) {
      memberNames[memberId] = userDoc.data()?['displayName'] as String? ?? 'Utilisateur';
    } else {
      memberNames[memberId] = 'Utilisateur';
    }
  }

  return memberNames;
});

/// Groups notifier for CRUD operations
final groupsNotifierProvider =
    StateNotifierProvider<GroupsNotifier, AsyncValue<void>>((ref) {
  return GroupsNotifier(
    ref.watch(firestoreProvider),
    ref,
  );
});

class GroupsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  GroupsNotifier(this._firestore, this._ref) : super(const AsyncValue.data(null));

  Future<String?> createGroup({
    required String name,
    String? description,
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
      final groupId = const Uuid().v4();

      final group = GroupModel(
        id: groupId,
        name: name,
        description: description,
        createdBy: user.uid,
        createdAt: now,
        updatedAt: now,
        memberIds: [user.uid],
        currency: currency,
        simplifyDebts: true,
      );

      // Create group document
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .set(group.toFirestore());

      // Create member subcollection entry
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .doc(user.uid)
          .set({
        'joinedAt': Timestamp.fromDate(now),
        'role': 'admin',
        'balance': 0,
      });

      state = const AsyncValue.data(null);
      return groupId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
  }) async {
    state = const AsyncValue.loading();

    try {
      final updates = <String, dynamic>{
        FirebaseConstants.updatedAt: Timestamp.now(),
      };

      if (name != null) updates[FirebaseConstants.groupName] = name;
      if (description != null) {
        updates[FirebaseConstants.groupDescription] = description;
      }

      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .update(updates);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMember({
    required String groupId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final now = DateTime.now();

      // Update group memberIds
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .update({
        FirebaseConstants.groupMemberIds: FieldValue.arrayUnion([userId]),
        FirebaseConstants.updatedAt: Timestamp.fromDate(now),
      });

      // Create member subcollection entry
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .doc(userId)
          .set({
        'joinedAt': Timestamp.fromDate(now),
        'role': 'member',
        'balance': 0,
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Update group memberIds
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .update({
        FirebaseConstants.groupMemberIds: FieldValue.arrayRemove([userId]),
        FirebaseConstants.updatedAt: Timestamp.now(),
      });

      // Delete member subcollection entry
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .doc(userId)
          .delete();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteGroup(String groupId) async {
    state = const AsyncValue.loading();

    try {
      // Delete all expenses
      final expenses = await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.expensesSubcollection)
          .get();

      for (final doc in expenses.docs) {
        await doc.reference.delete();
      }

      // Delete all members
      final members = await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .get();

      for (final doc in members.docs) {
        await doc.reference.delete();
      }

      // Delete group
      await _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .delete();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
