import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leguejuste/core/constants/firebase_constants.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/friends/presentation/providers/friends_provider.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'current-user-id';
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

  /// Helper: create a user document in Firestore
  Future<void> createUser({
    required String userId,
    required String phoneNumber,
    String displayName = 'Test User',
    String qrCode = 'QR-TEST',
  }) async {
    await fakeFirestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId)
        .set({
      FirebaseConstants.phoneNumber: phoneNumber,
      FirebaseConstants.displayName: displayName,
      FirebaseConstants.qrCode: qrCode,
      FirebaseConstants.createdAt: Timestamp.now(),
    });
  }

  /// Helper: make two users friends
  Future<void> makeFriends(String userId1, String userId2) async {
    final now = Timestamp.now();
    await fakeFirestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId1)
        .collection('friends')
        .doc(userId2)
        .set({'addedAt': now});
    await fakeFirestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId2)
        .collection('friends')
        .doc(userId1)
        .set({'addedAt': now});
  }

  group('FriendsNotifier.sendFriendRequest', () {
    test('creates friend request when user exists and is not already a friend', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101', displayName: 'Me');
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707', displayName: 'Friend');

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.sendFriendRequest('+2250707070707');

      expect(result, isTrue);

      // Verify friend request was created in target's subcollection
      final requests = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('friend-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .get();
      expect(requests.docs, hasLength(1));
      expect(requests.docs.first.data()['fromUserId'], 'current-user-id');
      expect(requests.docs.first.data()['status'], 'pending');

      // Verify notification was created for target
      final notifs = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('friend-id')
          .collection('notifications')
          .get();
      expect(notifs.docs, hasLength(1));
      expect(notifs.docs.first.data()['type'], FirebaseConstants.friendRequestType);
    });

    test('returns false when no user found with that phone number', () async {
      await waitForAuth();

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.sendFriendRequest('+2250000000000');

      expect(result, isFalse);

      final state = container.read(friendsNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('non trouvé'));
    });

    test('returns false when trying to add yourself', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101');

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.sendFriendRequest('+2250101010101');

      expect(result, isFalse);

      final state = container.read(friendsNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('vous-même'));
    });

    test('returns false when already friends', () async {
      await waitForAuth();
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707');
      await makeFriends('current-user-id', 'friend-id');

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.sendFriendRequest('+2250707070707');

      expect(result, isFalse);

      final state = container.read(friendsNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('Déjà'));
    });

    test('returns false when request already pending', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101', displayName: 'Me');
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707');

      // Create an existing pending request
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('friend-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .add({
        'fromUserId': 'current-user-id',
        'fromDisplayName': 'Me',
        'fromPhoneNumber': '+2250101010101',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.sendFriendRequest('+2250707070707');

      expect(result, isFalse);

      final state = container.read(friendsNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('Demande déjà envoyée'));
    });

    test('sets loading state during operation', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101', displayName: 'Me');
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707');

      final notifier = container.read(friendsNotifierProvider.notifier);

      final future = notifier.sendFriendRequest('+2250707070707');

      final stateBeforeAwait = container.read(friendsNotifierProvider);
      expect(stateBeforeAwait.isLoading, isTrue);

      await future;

      final stateAfterAwait = container.read(friendsNotifierProvider);
      expect(stateAfterAwait.hasValue, isTrue);
    });

    test('does not create friendship docs (only request)', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101', displayName: 'Me');
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707');

      final notifier = container.read(friendsNotifierProvider.notifier);
      await notifier.sendFriendRequest('+2250707070707');

      // Verify NO friendship was created yet
      final friendsDocs = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection('friends')
          .get();
      expect(friendsDocs.docs, isEmpty);
    });
  });

  group('FriendsNotifier.acceptFriendRequest', () {
    test('creates mutual friendship on accept', () async {
      await waitForAuth();
      await createUser(userId: 'current-user-id', phoneNumber: '+2250101010101', displayName: 'Me');
      await createUser(userId: 'requester-id', phoneNumber: '+2250707070707', displayName: 'Requester');

      // Create a pending request
      final requestRef = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .add({
        'fromUserId': 'requester-id',
        'fromDisplayName': 'Requester',
        'fromPhoneNumber': '+2250707070707',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final request = FriendRequestEntity(
        id: requestRef.id,
        fromUserId: 'requester-id',
        fromDisplayName: 'Requester',
        fromPhoneNumber: '+2250707070707',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.acceptFriendRequest(request);

      expect(result, isTrue);

      // Verify mutual friendship
      final side1 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection('friends')
          .doc('requester-id')
          .get();
      expect(side1.exists, isTrue);

      final side2 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('requester-id')
          .collection('friends')
          .doc('current-user-id')
          .get();
      expect(side2.exists, isTrue);

      // Verify request status updated
      final updatedRequest = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .doc(requestRef.id)
          .get();
      expect(updatedRequest.data()?['status'], 'accepted');
    });
  });

  group('FriendsNotifier.declineFriendRequest', () {
    test('updates request status to declined', () async {
      await waitForAuth();

      final requestRef = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .add({
        'fromUserId': 'requester-id',
        'fromDisplayName': 'Requester',
        'fromPhoneNumber': '+2250707070707',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.declineFriendRequest(requestRef.id);

      expect(result, isTrue);

      final updatedRequest = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection(FirebaseConstants.friendRequestsSubcollection)
          .doc(requestRef.id)
          .get();
      expect(updatedRequest.data()?['status'], 'declined');
    });
  });

  group('FriendsNotifier.addFriendByQrCode', () {
    test('adds friend by QR code successfully (direct, no request)', () async {
      await waitForAuth();
      await createUser(
        userId: 'qr-friend-id',
        phoneNumber: '+2250808080808',
        displayName: 'QR Friend',
        qrCode: 'LGJ-12345678-abc',
      );

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.addFriendByQrCode('LGJ-12345678-abc');

      expect(result, isTrue);

      final friendDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection('friends')
          .doc('qr-friend-id')
          .get();
      expect(friendDoc.exists, isTrue);
    });

    test('returns false for non-existent QR code', () async {
      await waitForAuth();

      final notifier = container.read(friendsNotifierProvider.notifier);
      final result = await notifier.addFriendByQrCode('LGJ-NONEXISTENT');

      expect(result, isFalse);
    });
  });

  group('FriendsNotifier.removeFriend', () {
    test('removes mutual friendship', () async {
      await waitForAuth();
      await createUser(userId: 'friend-id', phoneNumber: '+2250707070707');
      await makeFriends('current-user-id', 'friend-id');

      final notifier = container.read(friendsNotifierProvider.notifier);
      await notifier.removeFriend('friend-id');

      final side1 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection('friends')
          .doc('friend-id')
          .get();
      expect(side1.exists, isFalse);

      final side2 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('friend-id')
          .collection('friends')
          .doc('current-user-id')
          .get();
      expect(side2.exists, isFalse);
    });
  });

  group('userFriendsProvider', () {
    test('returns empty list when user has no friends', () async {
      await waitForAuth();

      final friends = await container.read(userFriendsProvider.future);
      expect(friends, isEmpty);
    });

    test('returns friends list with user data', () async {
      await waitForAuth();
      await createUser(
        userId: 'friend-1',
        phoneNumber: '+2250707070707',
        displayName: 'Alice',
        qrCode: 'QR-ALICE',
      );

      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('current-user-id')
          .collection('friends')
          .doc('friend-1')
          .set({'addedAt': Timestamp.now()});

      final friends = await container.read(userFriendsProvider.future);

      expect(friends, hasLength(1));
      expect(friends.first.id, 'friend-1');
      expect(friends.first.displayName, 'Alice');
      expect(friends.first.qrCode, 'QR-ALICE');
    });
  });
}
