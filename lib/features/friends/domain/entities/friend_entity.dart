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
