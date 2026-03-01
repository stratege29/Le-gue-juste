import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leguejuste/core/constants/firebase_constants.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/groups/presentation/providers/groups_provider.dart';

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

  /// Wait for authStateProvider to emit the mock user
  Future<void> waitForAuth() async {
    // Reading the future form forces the stream to emit and settle
    await container.read(authStateProvider.future);
  }

  group('GroupsNotifier.createGroup', () {
    test('default currency is XOF', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(name: 'Test Group');

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      expect(doc.data()?['currency'], 'XOF');
    });

    test('stores imageUrl in group document', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Restaurant Group',
        imageUrl: 'icon:restaurant',
      );

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      expect(doc.data()?['imageUrl'], 'icon:restaurant');
    });

    test('creates group with creator as only member when no extraMemberIds', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(name: 'Solo Group');

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      final memberIds = List<String>.from(doc.data()?['memberIds'] ?? []);
      expect(memberIds, ['test-user-id']);
    });

    test('adds extraMemberIds to group memberIds', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Friend Group',
        extraMemberIds: ['friend-1', 'friend-2'],
      );

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      final memberIds = List<String>.from(doc.data()?['memberIds'] ?? []);
      expect(memberIds, ['test-user-id', 'friend-1', 'friend-2']);
    });

    test('creates member subcollection entries for extra members', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Friend Group',
        extraMemberIds: ['friend-1', 'friend-2'],
      );

      expect(groupId, isNotNull);

      // Check creator entry
      final creatorDoc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .collection(FirebaseConstants.membersSubcollection)
          .doc('test-user-id')
          .get();
      expect(creatorDoc.exists, isTrue);
      expect(creatorDoc.data()?['role'], 'admin');

      // Check friend-1 entry
      final friend1Doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .doc('friend-1')
          .get();
      expect(friend1Doc.exists, isTrue);
      expect(friend1Doc.data()?['role'], 'member');
      expect(friend1Doc.data()?['balance'], 0);

      // Check friend-2 entry
      final friend2Doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId)
          .collection(FirebaseConstants.membersSubcollection)
          .doc('friend-2')
          .get();
      expect(friend2Doc.exists, isTrue);
      expect(friend2Doc.data()?['role'], 'member');
    });

    test('accepts custom currency', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Euro Group',
        currency: 'EUR',
      );

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      expect(doc.data()?['currency'], 'EUR');
    });

    test('stores description when provided', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Described Group',
        description: 'A test description',
      );

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      expect(doc.data()?['description'], 'A test description');
    });

    test('all parameters together work correctly', () async {
      await waitForAuth();
      final notifier = container.read(groupsNotifierProvider.notifier);

      final groupId = await notifier.createGroup(
        name: 'Full Group',
        description: 'Full description',
        currency: 'USD',
        imageUrl: 'icon:flight',
        extraMemberIds: ['friend-a'],
      );

      expect(groupId, isNotNull);
      final doc = await fakeFirestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId!)
          .get();
      final data = doc.data()!;
      expect(data['name'], 'Full Group');
      expect(data['description'], 'Full description');
      expect(data['currency'], 'USD');
      expect(data['imageUrl'], 'icon:flight');
      expect(List<String>.from(data['memberIds']), ['test-user-id', 'friend-a']);
    });
  });
}
