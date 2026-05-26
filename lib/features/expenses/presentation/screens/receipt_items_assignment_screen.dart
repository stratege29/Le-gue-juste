import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../domain/entities/receipt_item.dart';
import 'receipt_scanner_screen.dart' show ReceiptScanResult;

/// Lets the user edit detected items and assign participants to each.
/// On validate, builds a [ReceiptScanResult] with per-user amounts (each item
/// split equally between its assignees).
class ReceiptItemsAssignmentScreen extends StatefulWidget {
  final ScannedReceipt receipt;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String? currentUserId;
  final String currency;

  const ReceiptItemsAssignmentScreen({
    super.key,
    required this.receipt,
    required this.memberIds,
    required this.memberNames,
    required this.currentUserId,
    required this.currency,
  });

  @override
  State<ReceiptItemsAssignmentScreen> createState() =>
      _ReceiptItemsAssignmentScreenState();
}

class _ReceiptItemsAssignmentScreenState
    extends State<ReceiptItemsAssignmentScreen> {
  late List<ReceiptItem> _items;

  String get _currencySymbol =>
      AppConstants.currencySymbols[widget.currency] ?? widget.currency;

  @override
  void initState() {
    super.initState();
    // Default: every detected item assigned to everyone.
    _items = widget.receipt.items
        .map((it) => it.copyWith(assignedUserIds: List.of(widget.memberIds)))
        .toList();
  }

  double get _itemsTotal =>
      _items.fold(0, (sum, it) => sum + it.total);

  Map<String, double> _computeUserTotals() {
    final totals = <String, double>{
      for (final id in widget.memberIds) id: 0,
    };
    for (final item in _items) {
      if (item.assignedUserIds.isEmpty) continue;
      final share = item.total / item.assignedUserIds.length;
      for (final uid in item.assignedUserIds) {
        totals[uid] = (totals[uid] ?? 0) + share;
      }
    }
    return totals;
  }

  void _toggleAssignment(String itemId, String userId) {
    HapticFeedback.selectionClick();
    setState(() {
      _items = _items.map((it) {
        if (it.id != itemId) return it;
        final assigned = List<String>.from(it.assignedUserIds);
        if (assigned.contains(userId)) {
          assigned.remove(userId);
        } else {
          assigned.add(userId);
        }
        return it.copyWith(assignedUserIds: assigned);
      }).toList();
    });
  }

  void _assignAllTo(String itemId, List<String> userIds) {
    setState(() {
      _items = _items.map((it) {
        if (it.id != itemId) return it;
        return it.copyWith(assignedUserIds: List.of(userIds));
      }).toList();
    });
  }

  void _deleteItem(String itemId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _items = _items.where((it) => it.id != itemId).toList();
    });
  }

  Future<void> _editItem(ReceiptItem item) async {
    final updated = await showModalBottomSheet<ReceiptItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(item: item, currency: widget.currency),
    );
    if (updated != null) {
      setState(() {
        _items = _items.map((it) => it.id == item.id ? updated : it).toList();
      });
    }
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<ReceiptItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(
        item: ReceiptItem(name: '', price: 0, assignedUserIds: widget.memberIds),
        currency: widget.currency,
        isNew: true,
      ),
    );
    if (created != null) {
      setState(() {
        _items = [..._items, created];
      });
    }
  }

  void _confirm() {
    if (_items.isEmpty) {
      SnackbarManager.showError(context, "Ajoutez au moins un article.");
      return;
    }
    final unassigned = _items.where((it) => it.assignedUserIds.isEmpty).toList();
    if (unassigned.isNotEmpty) {
      SnackbarManager.showError(
        context,
        "${unassigned.length} article(s) sans participant. Assignez-les ou supprimez-les.",
      );
      return;
    }

    final userTotals = _computeUserTotals();
    // Drop entries where the user owes nothing (they're not participants).
    final filtered = <String, double>{
      for (final e in userTotals.entries)
        if (e.value > 0) e.key: _round(e.value),
    };
    _absorbRoundingDrift(filtered, _round(_itemsTotal));

    // Description = "Reçu (N articles)"
    final desc = _items.length == 1
        ? 'Reçu: ${_items.first.name}'
        : 'Reçu (${_items.length} articles)';

    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      ReceiptScanResult(
        totalAmount: _round(_itemsTotal),
        amountsPerUser: filtered,
        description: desc,
      ),
    );
  }

  static double _round(double v) => (v * 100).round() / 100;

  /// Ensures the sum of per-user amounts exactly equals [target] after
  /// rounding by giving the residual cent(s) to the largest share.
  static void _absorbRoundingDrift(
      Map<String, double> amounts, double target) {
    if (amounts.isEmpty) return;
    final sum = amounts.values.fold<double>(0, (s, v) => s + v);
    final diff = _round(target - sum);
    if (diff == 0) return;
    final largest = amounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    amounts[largest] = _round((amounts[largest] ?? 0) + diff);
  }

  String _displayName(String userId) {
    if (userId == widget.currentUserId) return 'Moi';
    return widget.memberNames[userId] ?? 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    final userTotals = _computeUserTotals();
    final detected = widget.receipt.detectedTotal;
    final totalDiff = detected != null ? (detected - _itemsTotal).abs() : 0;
    final hasDiscrepancy = detected != null && totalDiff > 0.5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles détectés'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un article',
            icon: const Icon(Icons.add_rounded),
            onPressed: _addItem,
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasDiscrepancy) _buildDiscrepancyBanner(detected),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _items.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return _buildAddItemButton();
                }
                return _buildItemCard(_items[index]);
              },
            ),
          ),
          _buildSummaryBar(userTotals),
        ],
      ),
    );
  }

  Widget _buildDiscrepancyBanner(double detected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Total détecté: ${detected.toStringAsFixed(2)} $_currencySymbol — '
              'somme des articles: ${_itemsTotal.toStringAsFixed(2)} $_currencySymbol. '
              'Vérifiez ou ajoutez les articles manquants.',
              style: const TextStyle(fontSize: 13, color: AppColors.gray800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ReceiptItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: name, price, edit, delete
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editItem(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.quantity > 1
                              ? '${item.quantity}× ${item.name}'
                              : item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.total.toStringAsFixed(2)} $_currencySymbol',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: AppColors.gray500),
                  onPressed: () => _editItem(item),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.error),
                  onPressed: () => _deleteItem(item.id),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Participants row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pour qui ?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray600,
                      ),
                    ),
                    const Spacer(),
                    if (item.assignedUserIds.length < widget.memberIds.length)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            _assignAllTo(item.id, widget.memberIds),
                        child: const Text('Tous'),
                      )
                    else
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _assignAllTo(item.id, const []),
                        child: const Text('Aucun'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.memberIds.map((uid) {
                    final isSelected = item.assignedUserIds.contains(uid);
                    return FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _displayName(uid),
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.gray800,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.gray100,
                      checkmarkColor: Colors.white,
                      side: BorderSide.none,
                      onSelected: (_) => _toggleAssignment(item.id, uid),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_rounded),
      label: const Text('Ajouter un article'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: AppColors.gray300, style: BorderStyle.solid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _addItem,
    );
  }

  Widget _buildSummaryBar(Map<String, double> userTotals) {
    final activeUsers = userTotals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.gray600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_itemsTotal.toStringAsFixed(2)} $_currencySymbol',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray900,
                        ),
                  ),
                ],
              ),
              if (activeUsers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeUsers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final entry = activeUsers[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displayName(entry.key),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${entry.value.toStringAsFixed(2)} $_currencySymbol',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _confirm,
                  child: const Text(
                    'Valider et continuer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditItemSheet extends StatefulWidget {
  final ReceiptItem item;
  final String currency;
  final bool isNew;

  const _EditItemSheet({
    required this.item,
    required this.currency,
    this.isNew = false,
  });

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _qty;

  String get _symbol =>
      AppConstants.currencySymbols[widget.currency] ?? widget.currency;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _price = TextEditingController(
        text: widget.item.price == 0 ? '' : widget.item.price.toStringAsFixed(2));
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
    final qty = int.tryParse(_qty.text) ?? 1;
    if (name.isEmpty) {
      SnackbarManager.showError(context, "Le nom est requis.");
      return;
    }
    if (price <= 0) {
      SnackbarManager.showError(context, "Prix invalide.");
      return;
    }
    Navigator.pop(
      context,
      widget.item.copyWith(name: name, price: price, quantity: qty.clamp(1, 99)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.isNew ? 'Nouvel article' : 'Modifier l\'article',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom',
                hintText: 'Ex: Pizza margherita',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Prix unitaire',
                      suffixText: _symbol,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qté'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: Text(widget.isNew ? 'Ajouter' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
