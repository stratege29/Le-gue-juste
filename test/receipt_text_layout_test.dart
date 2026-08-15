import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/expenses/data/services/receipt_parser.dart';
import 'package:leguejuste/features/expenses/data/services/receipt_text_layout.dart';

/// Builds a line box: a row `index` tall of `height`, spanning [left, right].
OcrLine line(String text, {required double left, required double right,
    required double top, double height = 20}) {
  return OcrLine(
    text: text,
    box: Rect.fromLTRB(left, top, right, top + height),
  );
}

void main() {
  group('ReceiptTextLayout.toRows', () {
    test('réunit la colonne des libellés et celle des prix', () {
      // Ce que ML Kit renvoie sur un ticket 2 colonnes : un bloc de libellés,
      // puis un bloc de prix — d'où l'ordre volontairement mélangé ici.
      final rows = ReceiptTextLayout.toRows([
        line('Attieke poisson', left: 10, right: 200, top: 0),
        line('Poulet braise', left: 10, right: 200, top: 30),
        line('Alloco', left: 10, right: 200, top: 60),
        line('3 000', left: 300, right: 380, top: 0),
        line('4 000', left: 300, right: 380, top: 30),
        line('1 500', left: 300, right: 380, top: 60),
      ]);

      expect(rows, 'Attieke poisson  3 000\n'
          'Poulet braise  4 000\n'
          'Alloco  1 500');
    });

    test('ordonne les fragments de gauche à droite', () {
      final rows = ReceiptTextLayout.toRows([
        line('2,50', left: 300, right: 380, top: 0),
        line('Pain', left: 10, right: 100, top: 0),
      ]);

      expect(rows, 'Pain  2,50');
    });

    test('garde des lignes distinctes quand elles ne se chevauchent pas', () {
      final rows = ReceiptTextLayout.toRows([
        line('Pain 2,50', left: 10, right: 380, top: 0),
        line('Lait 1,20', left: 10, right: 380, top: 30),
      ]);

      expect(rows, 'Pain 2,50\nLait 1,20');
    });

    test('tolère un léger décalage vertical entre colonnes', () {
      // Le prix est 6px plus bas que son libellé : même rangée malgré tout.
      final rows = ReceiptTextLayout.toRows([
        line('Baguette', left: 10, right: 200, top: 0),
        line('1,20', left: 300, right: 380, top: 6),
      ]);

      expect(rows, 'Baguette  1,20');
    });

    test('ignore les lignes vides', () {
      final rows = ReceiptTextLayout.toRows([
        line('Pain', left: 10, right: 100, top: 0),
        line('   ', left: 200, right: 250, top: 0),
        line('2,50', left: 300, right: 380, top: 0),
      ]);

      expect(rows, 'Pain  2,50');
    });

    test('renvoie une chaîne vide sans ligne exploitable', () {
      expect(ReceiptTextLayout.toRows([]), '');
    });

    test('bout en bout : ticket 2 colonnes correctement parsé', () {
      final rows = ReceiptTextLayout.toRows([
        line('Attieke poisson', left: 10, right: 200, top: 0),
        line('Alloco', left: 10, right: 200, top: 30),
        line('TOTAL', left: 10, right: 200, top: 70),
        line('3 000', left: 300, right: 380, top: 0),
        line('1 500', left: 300, right: 380, top: 30),
        line('4 500', left: 300, right: 380, top: 70),
      ]);
      final receipt = ReceiptParser.parse(rows);

      expect(receipt.detectedTotal, 4500);
      expect(receipt.items.map((e) => e.name).toList(),
          ['Attieke Poisson', 'Alloco']);
      expect(receipt.itemsSum, 4500);
    });
  });
}
