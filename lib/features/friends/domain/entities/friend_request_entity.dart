/// Friend request entity
class FriendRequestEntity {
  final String id;
  final String fromUserId;
  final String fromDisplayName;
  final String fromPhoneNumber;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  FriendRequestEntity({
    required this.id,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.fromPhoneNumber,
    required this.status,
    required this.createdAt,
  });
}
