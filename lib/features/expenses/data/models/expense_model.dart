import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense_entity.dart';

class ExpenseModel {
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
  final String splitType;
  final List<ExpenseSplitModel> splits;
  final bool isDeleted;

  const ExpenseModel({
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

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc, String groupId) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse splits from map - handle both old format (just numbers) and new format (map with amount/percentage/isPaid)
    final splitsData = data['splits'] as Map<String, dynamic>? ?? {};
    final splits = splitsData.entries.map((entry) {
      // Check if value is a number (old format) or a map (new format)
      if (entry.value is num) {
        // Old format: just a number representing the amount
        return ExpenseSplitModel(
          userId: entry.key,
          amount: (entry.value as num).toDouble(),
          percentage: null,
          isPaid: false,
        );
      } else {
        // New format: map with amount, percentage, isPaid
        final splitData = entry.value as Map<String, dynamic>;
        return ExpenseSplitModel(
          userId: entry.key,
          amount: (splitData['amount'] as num).toDouble(),
          percentage: (splitData['percentage'] as num?)?.toDouble(),
          isPaid: splitData['isPaid'] as bool? ?? false,
        );
      }
    }).toList();

    return ExpenseModel(
      id: doc.id,
      groupId: groupId,
      description: data['description'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'EUR',
      paidBy: data['paidBy'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] as String?,
      imageUrl: data['imageUrl'] as String?,
      splitType: data['splitType'] as String,
      splits: splits,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    // Convert splits to map format
    final splitsMap = <String, dynamic>{};
    for (final split in splits) {
      splitsMap[split.userId] = {
        'amount': split.amount,
        'percentage': split.percentage,
        'isPaid': split.isPaid,
      };
    }

    return {
      'description': description,
      'amount': amount,
      'currency': currency,
      'paidBy': paidBy,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'date': Timestamp.fromDate(date),
      'category': category,
      'imageUrl': imageUrl,
      'splitType': splitType,
      'splits': splitsMap,
      'isDeleted': isDeleted,
    };
  }

  ExpenseEntity toEntity() {
    return ExpenseEntity(
      id: id,
      groupId: groupId,
      description: description,
      amount: amount,
      currency: currency,
      paidBy: paidBy,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      date: date,
      category: category,
      imageUrl: imageUrl,
      splitType: SplitType.values.firstWhere((e) => e.name == splitType),
      splits: splits.map((s) => s.toEntity()).toList(),
      isDeleted: isDeleted,
    );
  }

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      groupId: entity.groupId,
      description: entity.description,
      amount: entity.amount,
      currency: entity.currency,
      paidBy: entity.paidBy,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      date: entity.date,
      category: entity.category,
      imageUrl: entity.imageUrl,
      splitType: entity.splitType.name,
      splits: entity.splits.map((s) => ExpenseSplitModel.fromEntity(s)).toList(),
      isDeleted: entity.isDeleted,
    );
  }
}

class ExpenseSplitModel {
  final String userId;
  final double amount;
  final double? percentage;
  final bool isPaid;

  const ExpenseSplitModel({
    required this.userId,
    required this.amount,
    this.percentage,
    this.isPaid = false,
  });

  ExpenseSplit toEntity() {
    return ExpenseSplit(
      userId: userId,
      amount: amount,
      percentage: percentage,
      isPaid: isPaid,
    );
  }

  factory ExpenseSplitModel.fromEntity(ExpenseSplit entity) {
    return ExpenseSplitModel(
      userId: entity.userId,
      amount: entity.amount,
      percentage: entity.percentage,
      isPaid: entity.isPaid,
    );
  }
}
