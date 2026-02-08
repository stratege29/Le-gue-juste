import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// The type of balance to display, which affects the gradient colors
enum BalanceType {
  /// User is owed money (green gradient)
  positive,

  /// User owes money (red gradient)
  negative,

  /// Balance is neutral (gray/primary gradient)
  neutral,
}

/// A reusable gradient summary card for displaying balance information.
///
/// Used across GroupDetailScreen, BalancesScreen, and SettleUpScreen.
class SummaryCard extends StatelessWidget {
  /// The label shown above the amount (e.g., "On vous doit")
  final String label;

  /// The amount to display
  final double amount;

  /// Currency symbol (e.g., "€", "$")
  final String currencySymbol;

  /// Type of balance (affects gradient colors)
  final BalanceType balanceType;

  /// Optional subtitle shown below the amount
  final String? subtitle;

  /// Optional action button
  final Widget? action;

  /// Whether to show absolute value of amount
  final bool showAbsoluteValue;

  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.currencySymbol,
    required this.balanceType,
    this.subtitle,
    this.action,
    this.showAbsoluteValue = true,
  });

  /// Factory constructor for balance cards that auto-determine the type
  factory SummaryCard.balance({
    Key? key,
    required double amount,
    required String currencySymbol,
    String? subtitle,
    Widget? action,
  }) {
    final isOwed = amount > 0.01;
    final owes = amount < -0.01;

    return SummaryCard(
      key: key,
      label: isOwed ? 'On vous doit' : owes ? 'Vous devez' : 'Solde',
      amount: amount,
      currencySymbol: currencySymbol,
      balanceType: isOwed
          ? BalanceType.positive
          : owes
              ? BalanceType.negative
              : BalanceType.neutral,
      subtitle: subtitle,
      action: action,
    );
  }

  List<Color> get _gradientColors {
    switch (balanceType) {
      case BalanceType.positive:
        return [const Color(0xFF22C55E), const Color(0xFF14B8A6)];
      case BalanceType.negative:
        return [const Color(0xFFEF4444), const Color(0xFFE11D48)];
      case BalanceType.neutral:
        return [AppColors.primary, const Color(0xFF7C3AED)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayAmount = showAbsoluteValue ? amount.abs() : amount;
    final formattedAmount = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    ).format(displayAmount);

    return Semantics(
      label: '$label: $formattedAmount',
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              formattedAmount,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A summary card specifically for debt summary (showing both "you owe" and "owed to you")
class DebtSummaryCard extends StatelessWidget {
  final double totalOwing;
  final double totalOwed;
  final String currencySymbol;

  const DebtSummaryCard({
    super.key,
    required this.totalOwing,
    required this.totalOwed,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Vous devez $currencySymbol${NumberFormat('#,##0').format(totalOwing)}. On vous doit $currencySymbol${NumberFormat('#,##0').format(totalOwed)}.',
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _DebtColumn(
                label: 'Vous devez',
                amount: totalOwing,
                currencySymbol: currencySymbol,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _DebtColumn(
                label: 'On vous doit',
                amount: totalOwed,
                currencySymbol: currencySymbol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;

  const _DebtColumn({
    required this.label,
    required this.amount,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$currencySymbol${NumberFormat('#,##0').format(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
