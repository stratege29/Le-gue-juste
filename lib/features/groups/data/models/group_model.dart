import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group_entity.dart';

class GroupModel {
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

  const GroupModel({
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

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      currency: data['currency'] as String? ?? 'EUR',
      simplifyDebts: data['simplifyDebts'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'memberIds': memberIds,
      'currency': currency,
      'simplifyDebts': simplifyDebts,
    };
  }

  GroupEntity toEntity() {
    return GroupEntity(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      memberIds: memberIds,
      currency: currency,
      simplifyDebts: simplifyDebts,
    );
  }

  factory GroupModel.fromEntity(GroupEntity entity) {
    return GroupModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      imageUrl: entity.imageUrl,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      memberIds: entity.memberIds,
      currency: entity.currency,
      simplifyDebts: entity.simplifyDebts,
    );
  }

  GroupModel copyWith({
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
    return GroupModel(
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
}
