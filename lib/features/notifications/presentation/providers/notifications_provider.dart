import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Notification entity
class NotificationEntity {
  final String id;
  final String type; // 'expense_added', 'group_invite', 'payment_received', 'payment_reminder'
  final String title;
  final String body;
  final String? groupId;
  final String? expenseId;
  final String? fromUserId;
  final DateTime createdAt;
  final bool isRead;

  NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.groupId,
    this.expenseId,
    this.fromUserId,
    required this.createdAt,
    required this.isRead,
  });
}

/// Stream of user's notifications
final userNotificationsProvider = StreamProvider<List<NotificationEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseConstants.usersCollection)
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return NotificationEntity(
              id: doc.id,
              type: data['type'] as String? ?? 'general',
              title: data['title'] as String? ?? '',
              body: data['body'] as String? ?? '',
              groupId: data['groupId'] as String?,
              expenseId: data['expenseId'] as String?,
              fromUserId: data['fromUserId'] as String?,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isRead: data['isRead'] as bool? ?? false,
            );
          }).toList());
});

/// Count of unread notifications
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(userNotificationsProvider);
  return notifications.whenOrNull(
        data: (list) => list.where((n) => !n.isRead).length,
      ) ??
      0;
});

/// Notifications notifier for operations
final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<void>>((ref) {
  return NotificationsNotifier(
    ref.watch(firestoreProvider),
    ref,
  );
});

class NotificationsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  NotificationsNotifier(this._firestore, this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) return;

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      // Silently fail for read status update
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) return;

      final unread = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) return;

      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final currentUser = _ref.read(authStateProvider).valueOrNull;
      if (currentUser == null) return;

      final all = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('notifications')
          .get();

      final batch = _firestore.batch();
      for (final doc in all.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }
}
