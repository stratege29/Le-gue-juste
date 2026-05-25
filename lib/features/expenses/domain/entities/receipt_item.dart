import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// A single line item detected on a receipt.
///
/// During the assignment step, [assignedUserIds] holds the participants who
/// will share this item's price (split equally between them).
class ReceiptItem extends Equatable {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final List<String> assignedUserIds;

  ReceiptItem({
    String? id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.assignedUserIds = const [],
  }) : id = id ?? const Uuid().v4();

  ReceiptItem copyWith({
    String? name,
    double? price,
    int? quantity,
    List<String>? assignedUserIds,
  }) {
    return ReceiptItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    );
  }

  double get total => price * quantity;

  @override
  List<Object?> get props => [id, name, price, quantity, assignedUserIds];
}

/// Container for the result of scanning a receipt.
///
/// [detectedTotal] is the total parsed from the receipt (TOTAL / TTC line),
/// when available. May differ from the sum of [items] if some items were
/// missed by OCR — the UI can warn the user.
class ScannedReceipt extends Equatable {
  final List<ReceiptItem> items;
  final double? detectedTotal;
  final String rawText;

  const ScannedReceipt({
    required this.items,
    this.detectedTotal,
    this.rawText = '',
  });

  double get itemsSum => items.fold(0, (sum, it) => sum + it.total);

  @override
  List<Object?> get props => [items, detectedTotal, rawText];
}
