import 'package:equatable/equatable.dart';

enum SplitType { equal, exact, percentage }

class ExpenseEntity extends Equatable {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currency;
  final String paidBy;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime date;
  final String? category;
  final String? imageUrl;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final bool isDeleted;

  const ExpenseEntity({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    this.currency = 'EUR',
    required this.paidBy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.date,
    this.category,
    this.imageUrl,
    required this.splitType,
    required this.splits,
    this.isDeleted = false,
  });

  ExpenseEntity copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? currency,
    String? paidBy,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? date,
    String? category,
    String? imageUrl,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    bool? isDeleted,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paidBy: paidBy ?? this.paidBy,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      date: date ?? this.date,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Get the list of participant IDs
  List<String> get participantIds => splits.map((s) => s.userId).toList();

  /// Get the split amount for a specific user
  double getSplitAmount(String userId) {
    final split = splits.firstWhere(
      (s) => s.userId == userId,
      orElse: () => ExpenseSplit(userId: userId, amount: 0),
    );
    return split.amount;
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        description,
        amount,
        currency,
        paidBy,
        createdBy,
        createdAt,
        updatedAt,
        date,
        category,
        imageUrl,
        splitType,
        splits,
        isDeleted,
      ];
}

class ExpenseSplit extends Equatable {
  final String userId;
  final double amount;
  final double? percentage;
  final bool isPaid;

  const ExpenseSplit({
    required this.userId,
    required this.amount,
    this.percentage,
    this.isPaid = false,
  });

  ExpenseSplit copyWith({
    String? userId,
    double? amount,
    double? percentage,
    bool? isPaid,
  }) {
    return ExpenseSplit(
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  @override
  List<Object?> get props => [userId, amount, percentage, isPaid];
}

/// Categories for expenses
class ExpenseCategory {
  static const String food = 'food';
  static const String transport = 'transport';
  static const String shopping = 'shopping';
  static const String entertainment = 'entertainment';
  static const String utilities = 'utilities';
  static const String rent = 'rent';
  static const String travel = 'travel';
  static const String health = 'health';
  static const String other = 'other';

  static const List<String> all = [
    food,
    transport,
    shopping,
    entertainment,
    utilities,
    rent,
    travel,
    health,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case food:
        return 'Nourriture';
      case transport:
        return 'Transport';
      case shopping:
        return 'Shopping';
      case entertainment:
        return 'Divertissement';
      case utilities:
        return 'Factures';
      case rent:
        return 'Loyer';
      case travel:
        return 'Voyage';
      case health:
        return 'Sante';
      case other:
      default:
        return 'Autre';
    }
  }
}
