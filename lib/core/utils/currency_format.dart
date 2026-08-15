import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formats monetary amounts according to the currency's minor unit.
///
/// The CFA franc has no subdivision, so rendering "13 750,00 CFA" is wrong —
/// amounts in XOF/XAF are shown without decimals.
class CurrencyFormat {
  CurrencyFormat._();

  static const Set<String> _zeroDecimalCurrencies = {'XOF', 'XAF'};

  /// Number of decimals to display for [currency].
  static int decimalDigits(String currency) =>
      _zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;

  static String symbol(String currency) =>
      AppConstants.currencySymbols[currency] ?? currency;

  /// Amount with thousands separators and the currency symbol,
  /// e.g. "13 750 CFA" or "1 234,50 €".
  static String format(double amount, String currency) {
    final digits = decimalDigits(currency);
    final pattern = digits == 0 ? '#,##0' : '#,##0.00';
    return '${NumberFormat(pattern, 'fr_FR').format(amount)} ${symbol(currency)}';
  }

  /// Bare value for prefilling a text field: no symbol and no thousands
  /// separator, so the result stays parseable by [double.tryParse].
  static String forInput(double amount, String currency) =>
      amount.toStringAsFixed(decimalDigits(currency));
}
