import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

export '../../domain/entities/friend_entity.dart';
export '../../domain/entities/friend_request_entity.dart';

import '../../domain/entities/friend_entity.dart';
import '../../domain/entities/friend_request_entity.dart';

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

/// Stream of pending friend requests received by current user
final pendingRequestsProvider = StreamProvider<List<FriendRequestEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.usersCollection)
      .doc(user.uid)
      .collection(FirebaseConstants.friendRequestsSubcollection)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return FriendRequestEntity(
              id: doc.id,
              fromUserId: data['fromUserId'] as String? ?? '',
              fromDisplayName: data['fromDisplayName'] as String? ?? 'Utilisateur',
              fromPhoneNumber: data['fromPhoneNumber'] as String? ?? '',
              status: data['status'] as String? ?? 'pending',
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList());
});

/// Count of pending friend requests
final pendingRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(pendingRequestsProvider);
  return requests.whenOrNull(data: (list) => list.length) ?? 0;
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

  /// Add friend directly via QR code (no request needed)
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

  /// Send a friend request by phone number (requires acceptance)
  Future<bool> sendFriendRequest(String phoneNumber) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecté', StackTrace.current);
        return false;
      }

      // Find user by phone number
      final userQuery = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FirebaseConstants.phoneNumber, isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        state = AsyncValue.error('Utilisateur non trouvé', StackTrace.current);
        return false;
      }

      final targetDoc = userQuery.docs.first;
      final targetId = targetDoc.id;

      if (targetId == currentUser.uid) {
        state = AsyncValue.error('Vous ne pouvez pas vous ajouter vous-même', StackTrace.current);
        return false;
      }

      // Check if already friends
      final existingFriend = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetId)
          .get();

      if (existingFriend.exists) {
        state = AsyncValue.error('Déjà dans vos amis', StackTrace.current);
        return false;
      }

      // Check if a pending request already exists from me to them
      final existingRequest = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(targetId)
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        state = AsyncValue.error('Demande déjà envoyée', StackTrace.current);
        return false;
      }

      // Check if there's a cross-request (they already sent me a request)
      final crossRequest = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .where('fromUserId', isEqualTo: targetId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (crossRequest.docs.isNotEmpty) {
        // Auto-accept: both users want to be friends
        final crossRequestDoc = crossRequest.docs.first;
        final crossRequestData = crossRequest.docs.first.data();
        await _acceptFriendRequestInternal(
          requestId: crossRequestDoc.id,
          fromUserId: targetId,
          fromDisplayName: crossRequestData['fromDisplayName'] as String? ?? 'Utilisateur',
        );
        state = const AsyncValue.data(null);
        return true;
      }

      // Get current user data for the request
      final currentUserDoc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .get();
      final currentUserData = currentUserDoc.data() ?? {};
      final myDisplayName = currentUserData[FirebaseConstants.displayName] as String? ?? 'Utilisateur';
      final myPhoneNumber = currentUserData[FirebaseConstants.phoneNumber] as String? ?? '';

      final now = DateTime.now();
      final batch = _firestore.batch();

      // Create friend request in target's subcollection
      final requestRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(targetId)
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .doc();

      batch.set(requestRef, {
        'fromUserId': currentUser.uid,
        'fromDisplayName': myDisplayName,
        'fromPhoneNumber': myPhoneNumber,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
      });

      // Create notification for the target
      final notifRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(targetId)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'type': FirebaseConstants.friendRequestType,
        'title': 'Demande d\'ami',
        'body': '$myDisplayName souhaite vous ajouter comme ami',
        'fromUserId': currentUser.uid,
        'requestId': requestRef.id,
        'createdAt': Timestamp.fromDate(now),
        'isRead': false,
      });

      await batch.commit();

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(FriendRequestEntity request) async {
    state = const AsyncValue.loading();
    try {
      await _acceptFriendRequestInternal(
        requestId: request.id,
        fromUserId: request.fromUserId,
        fromDisplayName: request.fromDisplayName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> _acceptFriendRequestInternal({
    required String requestId,
    required String fromUserId,
    required String fromDisplayName,
  }) async {
    final currentUser = _ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) throw Exception('Non connecté');

    // Get current user display name
    final currentUserDoc = await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(currentUser.uid)
        .get();
    final myDisplayName = currentUserDoc.data()?[FirebaseConstants.displayName] as String? ?? 'Utilisateur';

    final now = DateTime.now();
    final batch = _firestore.batch();

    // Create mutual friendship
    batch.set(
      _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .doc(fromUserId),
      {'addedAt': Timestamp.fromDate(now)},
    );

    batch.set(
      _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(fromUserId)
          .collection('friends')
          .doc(currentUser.uid),
      {'addedAt': Timestamp.fromDate(now)},
    );

    // Update request status to accepted
    batch.update(
      _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .doc(requestId),
      {'status': 'accepted'},
    );

    // Send notification to the requester that their request was accepted
    final notifRef = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(fromUserId)
        .collection('notifications')
        .doc();

    batch.set(notifRef, {
      'type': FirebaseConstants.friendRequestAcceptedType,
      'title': 'Demande acceptée',
      'body': '$myDisplayName a accepté votre demande d\'ami',
      'fromUserId': currentUser.uid,
      'createdAt': Timestamp.fromDate(now),
      'isRead': false,
    });

    // Delete the friend_request notification from my notifications
    final myNotifs = await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(currentUser.uid)
        .collection('notifications')
        .where('type', isEqualTo: FirebaseConstants.friendRequestType)
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();

    for (final doc in myNotifs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String requestId) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) {
        state = AsyncValue.error('Non connecté', StackTrace.current);
        return false;
      }

      final batch = _firestore.batch();

      // Update request status to declined
      batch.update(
        _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(currentUser.uid)
            .collection(FirebaseConstants.friendRequestsSubcollection)
            .doc(requestId),
        {'status': 'declined'},
      );

      // Delete the associated notification
      final myNotifs = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('notifications')
          .where('type', isEqualTo: FirebaseConstants.friendRequestType)
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();

      for (final doc in myNotifs.docs) {
        batch.delete(doc.reference);
      }

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
