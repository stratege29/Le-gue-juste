import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/expenses/domain/entities/receipt_item.dart';
import 'package:leguejuste/features/expenses/presentation/screens/receipt_items_assignment_screen.dart';
import 'package:leguejuste/features/expenses/presentation/screens/receipt_scanner_screen.dart';

/// Pumps the assignment screen, optionally interacts with it, then taps
/// "Valider et continuer" and returns the produced [ReceiptScanResult].
Future<ReceiptScanResult?> _runFlow(
  WidgetTester tester, {
  required List<ReceiptItem> items,
  required List<String> memberIds,
  double? detectedTotal,
  String currency = 'EUR',
  Future<void> Function(WidgetTester)? interact,
}) async {
  ReceiptScanResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(context).push<ReceiptScanResult>(
              MaterialPageRoute(
                builder: (_) => ReceiptItemsAssignmentScreen(
                  receipt: ScannedReceipt(
                    items: items,
                    detectedTotal: detectedTotal,
                  ),
                  memberIds: memberIds,
                  memberNames: {for (final id in memberIds) id: id},
                  currentUserId: null,
                  currency: currency,
                ),
              ),
            );
          },
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();

  if (interact != null) await interact(tester);

  await tester.tap(find.text('Valider et continuer'));
  await tester.pumpAndSettle();
  return result;
}

double _sum(Map<String, double> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  group('ReceiptItemsAssignmentScreen — répartition', () {
    testWidgets('par défaut, tous les articles sont partagés par tout le monde',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Attieke', price: 3000),
          ReceiptItem(id: 'b', name: 'Bissap', price: 750),
        ],
        memberIds: ['u1', 'u2', 'u3'],
        currency: 'XOF',
      );

      expect(result, isNotNull);
      expect(result!.totalAmount, 3750);
      expect(result.amountsPerUser, {'u1': 1250.0, 'u2': 1250.0, 'u3': 1250.0});
    });

    testWidgets('la somme des parts est exactement égale au total (arrondis)',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Pizza', price: 10.00),
          ReceiptItem(id: 'b', name: 'Coca', price: 3.33),
        ],
        memberIds: ['u1', 'u2', 'u3'],
      );

      // 13,33 / 3 ne tombe pas juste : le résidu va à la plus grosse part.
      expect(result!.totalAmount, 13.33);
      expect(_sum(result.amountsPerUser), closeTo(13.33, 0.0001));
      expect(result.amountsPerUser.values.toList(), [4.45, 4.44, 4.44]);
    });

    testWidgets('le résidu reste sous le centime même avec 7 participants',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          for (var i = 0; i < 12; i++)
            ReceiptItem(id: 'i$i', name: 'Item $i', price: 0.07),
        ],
        memberIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7'],
      );

      expect(_sum(result!.amountsPerUser),
          closeTo(result.totalAmount, 0.0001));
    });

    testWidgets('désassigner un participant reporte le coût sur les autres',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Homard', price: 45.00),
          ReceiptItem(id: 'b', name: 'Eau', price: 3.00),
        ],
        memberIds: ['u1', 'u2', 'u3'],
        interact: (t) async {
          // Retire u2 et u3 du homard (1re carte).
          await t.tap(find.byType(FilterChip).at(1));
          await t.pumpAndSettle();
          await t.tap(find.byType(FilterChip).at(2));
          await t.pumpAndSettle();
        },
      );

      expect(result!.totalAmount, 48.00);
      expect(result.amountsPerUser, {'u1': 46.0, 'u2': 1.0, 'u3': 1.0});
      expect(_sum(result.amountsPerUser), closeTo(48.00, 0.0001));
    });

    testWidgets('la quantité multiplie le prix unitaire', (tester) async {
      final result = await _runFlow(
        tester,
        items: [ReceiptItem(id: 'a', name: 'Biere', price: 4.00, quantity: 3)],
        memberIds: ['u1', 'u2'],
      );

      expect(result!.totalAmount, 12.00);
      expect(result.amountsPerUser, {'u1': 6.0, 'u2': 6.0});
    });

    testWidgets('une remise négative réduit les parts', (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Pain', price: 2.00),
          ReceiptItem(id: 'b', name: 'Remise', price: -0.50),
        ],
        memberIds: ['u1', 'u2'],
      );

      expect(result!.totalAmount, 1.50);
      expect(result.amountsPerUser, {'u1': 0.75, 'u2': 0.75});
      expect(_sum(result.amountsPerUser), closeTo(1.50, 0.0001));
    });

    testWidgets('la description reflète le nombre d\'articles', (tester) async {
      final one = await _runFlow(
        tester,
        items: [ReceiptItem(id: 'a', name: 'Biere', price: 4.00)],
        memberIds: ['u1'],
      );
      expect(one!.description, 'Reçu: Biere');

      final many = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Biere', price: 4.00),
          ReceiptItem(id: 'b', name: 'Coca', price: 3.00),
        ],
        memberIds: ['u1'],
      );
      expect(many!.description, 'Reçu (2 articles)');
    });
  });

  group('ReceiptItemsAssignmentScreen — garde-fous', () {
    testWidgets('refuse de valider si un article n\'a aucun participant',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [ReceiptItem(id: 'a', name: 'Biere', price: 4.00)],
        memberIds: ['u1', 'u2'],
        interact: (t) async {
          await t.tap(find.text('Aucun')); // désassigne tout le monde
          await t.pumpAndSettle();
        },
      );

      expect(result, isNull);
      expect(find.textContaining('sans participant'), findsOneWidget);
    });

    testWidgets('refuse de valider si le total est nul ou négatif',
        (tester) async {
      final result = await _runFlow(
        tester,
        items: [
          ReceiptItem(id: 'a', name: 'Pain', price: 2.00),
          ReceiptItem(id: 'b', name: 'Remise', price: -2.00),
        ],
        memberIds: ['u1'],
      );

      expect(result, isNull);
      expect(find.textContaining('supérieur à 0'), findsOneWidget);
    });

    testWidgets('affiche la bannière d\'écart quand le total détecté diffère',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptItemsAssignmentScreen(
            receipt: ScannedReceipt(
              items: [ReceiptItem(id: 'a', name: 'Pain', price: 2.00)],
              detectedTotal: 9.00,
            ),
            memberIds: const ['u1'],
            memberNames: const {'u1': 'u1'},
            currentUserId: 'u1',
            currency: 'EUR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total détecté'), findsOneWidget);
    });
  });
}
