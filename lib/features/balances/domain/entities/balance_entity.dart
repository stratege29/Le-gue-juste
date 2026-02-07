import 'package:equatable/equatable.dart';

/// Represents the balance for a user
class BalanceEntity extends Equatable {
  final String userId;
  final double totalBalance; // positive = owed to user, negative = user owes
  final Map<String, double> balanceByUser; // userId -> amount
  final Map<String, double> balanceByGroup; // groupId -> amount

  const BalanceEntity({
    required this.userId,
    required this.totalBalance,
    required this.balanceByUser,
    required this.balanceByGroup,
  });

  /// User is owed money (positive balance)
  bool get isOwed => totalBalance > 0.01;

  /// User owes money (negative balance)
  bool get owes => totalBalance < -0.01;

  /// All settled (balance close to 0)
  bool get isSettled => totalBalance.abs() <= 0.01;

  @override
  List<Object?> get props => [
        userId,
        totalBalance,
        balanceByUser,
        balanceByGroup,
      ];
}

/// Represents a debt between two users
class DebtEntity extends Equatable {
  final String fromUserId; // Who owes
  final String toUserId; // Who is owed
  final double amount;
  final String? groupId; // null if global debt across all groups

  const DebtEntity({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.groupId,
  });

  @override
  List<Object?> get props => [fromUserId, toUserId, amount, groupId];
}

/// Group balance summary
class GroupBalanceSummary extends Equatable {
  final String groupId;
  final String groupName;
  final double totalExpenses;
  final double userBalance; // User's balance in this group
  final List<DebtEntity> debts;

  const GroupBalanceSummary({
    required this.groupId,
    required this.groupName,
    required this.totalExpenses,
    required this.userBalance,
    required this.debts,
  });

  @override
  List<Object?> get props => [
        groupId,
        groupName,
        totalExpenses,
        userBalance,
        debts,
      ];
}
