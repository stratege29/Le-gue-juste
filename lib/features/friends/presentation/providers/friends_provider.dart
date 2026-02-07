import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Friend entity
class FriendEntity {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String qrCode;
  final DateTime addedAt;

  FriendEntity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.qrCode,
    required this.addedAt,
  });
}

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
    final friends = <FriendEntity>[];

    for (final doc in snapshot.docs) {
      final friendId = doc.id;
      final friendDoc = await firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(friendId)
          .get();

      if (friendDoc.exists) {
        final data = friendDoc.data()!;
        friends.add(FriendEntity(
          id: friendId,
          displayName: data['displayName'] as String? ?? 'Utilisateur',
          avatarUrl: data['avatarUrl'] as String?,
          qrCode: data['qrCode'] as String? ?? '',
          addedAt: (doc.data()['addedAt'] as Timestamp).toDate(),
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
        state = AsyncValue.error('Non connecte', StackTrace.current);
        return false;
      }

      // Find user by qrCode
      final userQuery = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FirebaseConstants.qrCode, isEqualTo: qrCode)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        state = AsyncValue.error('Utilisateur non trouve', StackTrace.current);
        return false;
      }

      final friendId = userQuery.docs.first.id;

      if (friendId == currentUser.uid) {
        state = AsyncValue.error('Vous ne pouvez pas vous ajouter vous-meme', StackTrace.current);
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
        state = AsyncValue.error('Deja dans vos amis', StackTrace.current);
        return false;
      }

      final now = DateTime.now();

      // Add friend to current user
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .doc(friendId)
          .set({'addedAt': Timestamp.fromDate(now)});

      // Add current user to friend's list (mutual)
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(friendId)
          .collection('friends')
          .doc(currentUser.uid)
          .set({'addedAt': Timestamp.fromDate(now)});

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
        state = AsyncValue.error('Non connecte', StackTrace.current);
        return;
      }

      // Remove from current user's friends
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .doc(friendId)
          .delete();

      // Remove current user from friend's list
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(friendId)
          .collection('friends')
          .doc(currentUser.uid)
          .delete();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
