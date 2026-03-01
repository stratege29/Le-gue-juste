import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

export '../../domain/entities/friend_entity.dart';

import '../../domain/entities/friend_entity.dart';

/// Stream of user's friends
final userFriendsProvider = StreamProvider<List<FriendEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.usersCollection)
      .doc(user.uid)
      .collection('friends')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
    if (snapshot.docs.isEmpty) return <FriendEntity>[];

    // Build a map of friendId -> addedAt from the friends subcollection
    final addedAtMap = <String, DateTime>{};
    for (final doc in snapshot.docs) {
      addedAtMap[doc.id] = (doc.data()['addedAt'] as Timestamp).toDate();
    }

    final friendIds = addedAtMap.keys.toList();

    // Batch fetch user docs using whereIn (max 10 per query)
    final chunks = _chunk(friendIds, 10);
    final userDocs = await Future.wait(
      chunks.map((chunk) => firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get()),
    );

    // Build a map of userId -> user data
    final userDataMap = <String, Map<String, dynamic>>{};
    for (final querySnapshot in userDocs) {
      for (final doc in querySnapshot.docs) {
        userDataMap[doc.id] = doc.data();
      }
    }

    // Assemble friends list preserving original order
    final friends = <FriendEntity>[];
    for (final friendId in friendIds) {
      final data = userDataMap[friendId];
      if (data != null) {
        friends.add(FriendEntity(
          id: friendId,
          displayName: data['displayName'] as String? ?? 'Utilisateur',
          avatarUrl: data['avatarUrl'] as String?,
          qrCode: data['qrCode'] as String? ?? '',
          addedAt: addedAtMap[friendId]!,
        ));
      }
    }

    return friends;
  });
});

/// Friends notifier for CRUD operations
final friendsNotifierProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<void>>((ref) {
  return FriendsNotifier(
    ref.watch(firestoreProvider),
    ref,
  );
});

class FriendsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  FriendsNotifier(this._firestore, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addFriendByQrCode(String qrCode) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecté', StackTrace.current);
        return false;
      }

      // Find user by qrCode
      final userQuery = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FirebaseConstants.qrCode, isEqualTo: qrCode)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        state = AsyncValue.error('Utilisateur non trouvé', StackTrace.current);
        return false;
      }

      final friendId = userQuery.docs.first.id;

      if (friendId == currentUser.uid) {
        state = AsyncValue.error('Vous ne pouvez pas vous ajouter vous-même', StackTrace.current);
        return false;
      }

      // Check if already friends
      final existingFriend = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .doc(friendId)
          .get();

      if (existingFriend.exists) {
        state = AsyncValue.error('Déjà dans vos amis', StackTrace.current);
        return false;
      }

      final now = DateTime.now();
      final batch = _firestore.batch();

      // Add friend to current user
      batch.set(
        _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(currentUser.uid)
            .collection('friends')
            .doc(friendId),
        {'addedAt': Timestamp.fromDate(now)},
      );

      // Add current user to friend's list (mutual)
      batch.set(
        _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(friendId)
            .collection('friends')
            .doc(currentUser.uid),
        {'addedAt': Timestamp.fromDate(now)},
      );

      await batch.commit();

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> removeFriend(String friendId) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecté', StackTrace.current);
        return;
      }

      final batch = _firestore.batch();

      // Remove from current user's friends
      batch.delete(
        _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(currentUser.uid)
            .collection('friends')
            .doc(friendId),
      );

      // Remove current user from friend's list
      batch.delete(
        _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(friendId)
            .collection('friends')
            .doc(currentUser.uid),
      );

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
