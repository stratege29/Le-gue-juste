import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/settlements/domain/entities/settlement_entity.dart';
import 'package:leguejuste/features/settlements/presentation/widgets/payment_method_bottom_sheet.dart';

void main() {
  Widget buildTestApp({required Widget child}) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('PaymentMethodBottomSheet widget', () {
    testWidgets('displays title and both payment options', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Mode de paiement'), findsOneWidget);

      // Verify manual option
      expect(find.text('Confirmation manuelle'), findsOneWidget);
      expect(find.text('Espèces, virement, ou autre'), findsOneWidget);

      // Verify Wave option
      expect(find.text('Payer via Wave'), findsOneWidget);

      // Verify icons
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
      expect(find.byIcon(Icons.waves), findsOneWidget);

      // Verify chevron icons (one per option)
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('tapping manual option closes and returns manual',
        (tester) async {
      PaymentMethod? result;

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<PaymentMethod>(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmation manuelle'));
      await tester.pumpAndSettle();

      expect(result, PaymentMethod.manual);
      // Bottom sheet should be dismissed
      expect(find.text('Mode de paiement'), findsNothing);
    });

    testWidgets('dismissing bottom sheet returns null', (tester) async {
      PaymentMethod? result = PaymentMethod.manual; // Start with non-null

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<PaymentMethod>(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dismiss by tapping the barrier (scrim)
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Wave option shows not installed subtitle when Wave unavailable',
        (tester) async {
      // In test environment, canLaunchUrl will return false
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // In test, Wave won't be "installed"
      expect(
        find.text('Wave non installé sur cet appareil'),
        findsOneWidget,
      );
    });

    testWidgets('Wave option is visually dimmed when unavailable',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find Opacity widget wrapping Wave option (should be 0.4)
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      // At least one Opacity should be 0.4 (Wave disabled)
      final hasDisabledOpacity =
          opacityWidgets.any((o) => o.opacity == 0.4);
      expect(hasDisabledOpacity, true);
    });

    testWidgets('manual option has full opacity', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Manual option should have opacity 1.0
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      final hasFullOpacity = opacityWidgets.any((o) => o.opacity == 1.0);
      expect(hasFullOpacity, true);
    });
  });

  group('PaymentMethodBottomSheet accessibility', () {
    testWidgets('options have semantic labels', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const PaymentMethodBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Semantic labels are set on the tiles
      expect(
        find.bySemanticsLabel(RegExp('Confirmation manuelle')),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp('Payer via Wave')),
        findsWidgets,
      );
    });
  });
}
