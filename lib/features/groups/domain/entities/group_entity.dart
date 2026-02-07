import 'package:equatable/equatable.dart';

class GroupEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;
  final String currency;
  final bool simplifyDebts;

  const GroupEntity({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.memberIds,
    this.currency = 'EUR',
    this.simplifyDebts = true,
  });

  GroupEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? memberIds,
    String? currency,
    bool? simplifyDebts,
  }) {
    return GroupEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberIds: memberIds ?? this.memberIds,
      currency: currency ?? this.currency,
      simplifyDebts: simplifyDebts ?? this.simplifyDebts,
    );
  }

  int get memberCount => memberIds.length;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        createdBy,
        createdAt,
        updatedAt,
        memberIds,
        currency,
        simplifyDebts,
      ];
}

class GroupMemberEntity extends Equatable {
  final String userId;
  final String groupId;
  final DateTime joinedAt;
  final MemberRole role;
  final double cachedBalance;

  const GroupMemberEntity({
    required this.userId,
    required this.groupId,
    required this.joinedAt,
    this.role = MemberRole.member,
    this.cachedBalance = 0.0,
  });

  bool get isAdmin => role == MemberRole.admin;

  @override
  List<Object?> get props => [userId, groupId, joinedAt, role, cachedBalance];
}

enum MemberRole { admin, member }
