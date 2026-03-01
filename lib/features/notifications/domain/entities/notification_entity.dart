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
