import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/expenses/data/services/receipt_parser.dart';

/// Tests for the receipt OCR heuristic parser.
///
/// The second group ("bugs connus") documents defects found during the audit.
/// All of them are fixed; the tests now guard against regressions.
void main() {
  group('ReceiptParser — comportement attendu', () {
    test('parse un ticket de supermarché FR/EUR', () {
      final r = ReceiptParser.parse('''
CARREFOUR MARKET
12 RUE DE LA PAIX
Tel: 01 42 00 00 00
SIRET 123 456 789 00012

Baguette tradition        1,20
Lait demi-ecreme          0,99
Cafe moulu 250g           4,85

TVA 5,5%                  0,38
TOTAL A PAYER             7,04
CARTE BANCAIRE            7,04
MERCI DE VOTRE VISITE
''');

      expect(r.detectedTotal, 7.04);
      expect(r.items.map((e) => e.name).toList(),
          ['Baguette Tradition', 'Lait Demi-ecreme', 'Cafe Moulu 250g']);
      expect(r.items.map((e) => e.price).toList(), [1.20, 0.99, 4.85]);
      expect(r.itemsSum, closeTo(7.04, 0.001));
    });

    test('parse un ticket XOF avec séparateur de milliers', () {
      final r = ReceiptParser.parse('''
MAQUIS LE BON COIN
Attieke poisson       3 000
Alloco                1 500
Bissap                  750 FCFA
Eau minerale            500 F
TOTAL                 5 750 FCFA
''');

      expect(r.detectedTotal, 5750);
      expect(r.items.length, 4);
      expect(r.items.map((e) => e.price).toList(), [3000, 1500, 750, 500]);
    });

    test('ignore les lignes de métadonnées', () {
      final r = ReceiptParser.parse('''
Ticket n° 4521
Caisse 3
Le 12/05/2026 14:30
TVA 20%                   2,00
Especes                  10,00
Monnaie                   2,96
Pain                      2,00
''');

      expect(r.items.map((e) => e.name).toList(), ['Pain']);
    });

    test('extrait la quantité en tête de ligne', () {
      final r = ReceiptParser.parse('2 x Yaourt nature 3,40');

      expect(r.items.single.quantity, 2);
      expect(r.items.single.name, 'Yaourt Nature');
    });

    test('gère le point ET la virgule comme séparateur décimal', () {
      expect(ReceiptParser.parse('Riz basmati 3.49').items.single.price, 3.49);
      expect(ReceiptParser.parse('Riz basmati 3,49').items.single.price, 3.49);
      expect(ReceiptParser.parse('Riz basmati 12 500,50').items.single.price,
          12500.50);
    });

    test('préfère le plus grand total quand HT et TTC coexistent', () {
      final r = ReceiptParser.parse('''
Plat du jour             15,00
TOTAL HT                 13,64
TOTAL TTC                15,00
''');

      expect(r.detectedTotal, 15.00);
    });

    test('conserve les accents dans les noms', () {
      final r = ReceiptParser.parse('Crème brûlée 6,50\nPâté 4,20');

      expect(r.items.map((e) => e.name).toList(), ['Crème Brûlée', 'Pâté']);
    });

    test('renvoie un résultat vide sur une entrée vide', () {
      final r = ReceiptParser.parse('   \n\n  ');

      expect(r.items, isEmpty);
      expect(r.detectedTotal, isNull);
    });
  });

  group('ReceiptParser — bugs connus (audit)', () {
    test('BUG-1: la ligne SOUS-TOTAL est comptée comme un article', () {
      // _subtotalPattern exclut la ligne de la détection du total, mais elle
      // retombe ensuite dans l'extraction d'articles => ticket doublé.
      final r = ReceiptParser.parse('Pain 2,00\nSOUS-TOTAL 2,00\nTOTAL 2,00');

      expect(r.items.map((e) => e.name).toList(), ['Pain']);
      expect(r.itemsSum, 2.00);
    });

    test('BUG-1 (bis): "Sous total" écrit avec un espace', () {
      final r = ReceiptParser.parse('Pain 2,00\nSous total 2,00\nTOTAL 2,00');

      expect(r.items.map((e) => e.name).toList(), ['Pain']);
    });

    test('BUG-2: un nom finissant par un chiffre produit un prix fantôme', () {
      // "YAOURT X8" (pas de prix sur la ligne) devient un article à 8,00.
      final r = ReceiptParser.parse('YAOURT X8\nMOUCHOIRS N2');

      expect(r.items, isEmpty);
    });

    test('BUG-2 (bis): un prix précédé d\'un espace reste détecté', () {
      // Le garde-fou ne doit pas rejeter les prix légitimes, y compris collés
      // à leur devise ou avec un nom qui contient déjà des chiffres.
      final r = ReceiptParser.parse(
          'Pain 2,00\nSavon 500F\nRiz 5kg 7500F\nPack coca 6 4,50');

      expect(r.items.map((e) => e.price).toList(), [2.00, 500, 7500, 4.50]);
      expect(r.items.last.name, 'Pack Coca');
    });

    test('BUG-3: une remise négative devient un article positif', () {
      final r = ReceiptParser.parse('Pain 2,00\nREMISE -0,50\nTOTAL 1,50');

      expect(r.itemsSum, closeTo(1.50, 0.001));
      expect(r.items.last.name, 'Remise');
      expect(r.items.last.price, -0.50);
    });

    test('BUG-4: "A PAYER" seul n\'est pas reconnu comme total', () {
      final r = ReceiptParser.parse('Pain 2,00\nA PAYER 2,00');

      expect(r.detectedTotal, 2.00);
      expect(r.items.map((e) => e.name).toList(), ['Pain']);
    });

    test('BUG-4 (bis): "À PAYER" accentué est aussi reconnu', () {
      final r = ReceiptParser.parse('Pain 2,00\nÀ PAYER 2,00');

      expect(r.detectedTotal, 2.00);
      expect(r.items.map((e) => e.name).toList(), ['Pain']);
    });

    test('BUG-5: le prix d\'une ligne "N x" est un total, pas un prix unitaire',
        () {
      // Sur un ticket FR, "2 x Yaourt 3,40" veut dire 3,40 au total.
      // Le parser renvoie price=3,40 ET quantity=2 => 6,80 facturés.
      final r = ReceiptParser.parse('2 x Yaourt nature 3,40');

      expect(r.items.single.total, closeTo(3.40, 0.001));
      expect(r.items.single.price, closeTo(1.70, 0.001));
      expect(r.items.single.quantity, 2);
    });

    // BUG-6 (layout 2 colonnes) se corrige en amont du parser, en reconstruisant
    // les rangées à partir des positions : voir receipt_text_layout_test.dart.
  });
}
