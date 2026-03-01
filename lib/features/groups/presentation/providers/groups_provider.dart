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
  if (memberIds.isEmpty) return {};

  // Batch fetch user docs using whereIn (max 10 per query)
  final chunks = _chunk(memberIds, 10);
  final userDocs = await Future.wait(
    chunks.map((chunk) => firestore
        .collection(FirebaseConstants.usersCollection)
        .where(FieldPath.documentId, whereIn: chunk)
        .get()),
  );

  // Build member names map from results
  final memberNames = <String, String>{};
  final userDataMap = <String, Map<String, dynamic>>{};
  for (final querySnapshot in userDocs) {
    for (final doc in querySnapshot.docs) {
      userDataMap[doc.id] = doc.data();
    }
  }

  for (final memberId in memberIds) {
    final data = userDataMap[memberId];
    memberNames[memberId] = data?['displayName'] as String? ?? 'Utilisateur';
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
    String currency = 'XOF',
    String? imageUrl,
    List<String> extraMemberIds = const [],
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
        imageUrl: imageUrl,
        createdBy: user.uid,
        createdAt: now,
        updatedAt: now,
        memberIds: [user.uid, ...extraMemberIds],
        currency: currency,
        simplifyDebts: true,
      );

      // Batch write: group doc + all member subcollection entries atomically
      final batch = _firestore.batch();

      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId);
      batch.set(groupRef, group.toFirestore());

      // Member subcollection entry for creator
      final creatorMemberRef = groupRef
          .collection(FirebaseConstants.membersSubcollection)
          .doc(user.uid);
      batch.set(creatorMemberRef, {
        'joinedAt': Timestamp.fromDate(now),
        'role': 'admin',
        'balance': 0,
      });

      // Member subcollection entries for invited friends
      for (final memberId in extraMemberIds) {
        final memberRef = groupRef
            .collection(FirebaseConstants.membersSubcollection)
            .doc(memberId);
        batch.set(memberRef, {
          'joinedAt': Timestamp.fromDate(now),
          'role': 'member',
          'balance': 0,
        });
      }

      await batch.commit();

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
      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId);

      // Fetch all subcollections in parallel before batching deletes
      final results = await Future.wait([
        groupRef.collection(FirebaseConstants.expensesSubcollection).get(),
        groupRef.collection(FirebaseConstants.membersSubcollection).get(),
        groupRef.collection(FirebaseConstants.settlementsSubcollection).get(),
      ]);

      final expenses = results[0];
      final members = results[1];
      final settlements = results[2];

      // Batch delete all subcollection docs + group doc atomically
      final batch = _firestore.batch();

      for (final doc in expenses.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in members.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in settlements.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(groupRef);

      await batch.commit();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Splits a list into chunks of the given size.
List<List<T>> _chunk<T>(List<T> list, int size) {
  return List.generate(
    (list.length / size).ceil(),
    (i) => list.sublist(i * size, (i + 1) * size > list.length ? list.length : (i + 1) * size),
  );
}
