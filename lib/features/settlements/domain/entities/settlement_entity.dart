import 'package:equatable/equatable.dart';

enum SettlementStatus { pending, confirmed }

class SettlementEntity extends Equatable {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final SettlementStatus status;
  final String? note;

  const SettlementEntity({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.currency = 'EUR',
    required this.createdAt,
    this.confirmedAt,
    required this.status,
    this.note,
  });

  SettlementEntity copyWith({
    String? id,
    String? groupId,
    String? fromUserId,
    String? toUserId,
    double? amount,
    String? currency,
    DateTime? createdAt,
    DateTime? confirmedAt,
    SettlementStatus? status,
    String? note,
  }) {
    return SettlementEntity(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  bool get isConfirmed => status == SettlementStatus.confirmed;
  bool get isPending => status == SettlementStatus.pending;

  @override
  List<Object?> get props => [
        id,
        groupId,
        fromUserId,
        toUserId,
        amount,
        currency,
        createdAt,
        confirmedAt,
        status,
        note,
      ];
}
