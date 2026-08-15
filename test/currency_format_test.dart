import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/core/utils/currency_format.dart';

void main() {
  group('CurrencyFormat.decimalDigits', () {
    test('le franc CFA n\'a pas de subdivision', () {
      expect(CurrencyFormat.decimalDigits('XOF'), 0);
      expect(CurrencyFormat.decimalDigits('XAF'), 0);
      expect(CurrencyFormat.decimalDigits('xof'), 0);
    });

    test('les autres devises gardent 2 décimales', () {
      expect(CurrencyFormat.decimalDigits('EUR'), 2);
      expect(CurrencyFormat.decimalDigits('USD'), 2);
      expect(CurrencyFormat.decimalDigits('GBP'), 2);
    });
  });

  group('CurrencyFormat.format', () {
    test('XOF : ni décimales ni virgule', () {
      final out = CurrencyFormat.format(13750, 'XOF');

      expect(out, contains('CFA'));
      expect(out, isNot(contains(',')));
      expect(out, isNot(contains('.')));
      expect(out.replaceAll(RegExp(r'[^0-9]'), ''), '13750');
    });

    test('EUR : 2 décimales avec virgule décimale', () {
      final out = CurrencyFormat.format(1234.5, 'EUR');

      expect(out, contains('€'));
      expect(out, contains(',50'));
      expect(out.replaceAll(RegExp(r'[^0-9]'), ''), '123450');
    });

    test('arrondit à l\'unité en XOF', () {
      expect(
        CurrencyFormat.format(4583.33, 'XOF').replaceAll(RegExp(r'[^0-9]'), ''),
        '4583',
      );
    });

    test('devise inconnue : le code sert de symbole', () {
      expect(CurrencyFormat.format(10, 'JPY'), contains('JPY'));
    });
  });

  group('CurrencyFormat.forInput', () {
    test('reste parseable par double.tryParse', () {
      for (final currency in ['XOF', 'EUR', 'USD']) {
        final text = CurrencyFormat.forInput(1234.5, currency);

        expect(double.tryParse(text), isNotNull,
            reason: '"$text" doit être parseable ($currency)');
      }
    });

    test('pas de symbole ni de séparateur de milliers', () {
      expect(CurrencyFormat.forInput(13750, 'XOF'), '13750');
      expect(CurrencyFormat.forInput(1234.5, 'EUR'), '1234.50');
    });

    test('gère les montants négatifs (remises)', () {
      expect(double.tryParse(CurrencyFormat.forInput(-0.5, 'EUR')), -0.5);
    });
  });
}
