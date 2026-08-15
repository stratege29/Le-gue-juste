import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/widgets/loading_button.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );

/// The spinner animates forever, so [WidgetTester.pumpAndSettle] can never be
/// used while loading: pump past the 300ms width animation instead.
const _afterWidthAnimation = Duration(milliseconds: 400);

void main() {
  group('LoadingButton - loading transition', () {
    for (final style in LoadingButtonStyle.values) {
      testWidgets('does not throw when toggling loading ($style)',
          (tester) async {
        await tester.pumpWidget(wrap(LoadingButton(
          label: 'Créer le gazoil',
          isLoading: false,
          onPressed: () {},
          style: style,
          minHeight: 56,
        )));
        await tester.pumpAndSettle();

        await tester.pumpWidget(wrap(LoadingButton(
          label: 'Créer le gazoil',
          isLoading: true,
          onPressed: () {},
          style: style,
          minHeight: 56,
        )));

        // Pump mid-animation: this is where interpolating towards
        // double.infinity used to assert with
        // "Cannot interpolate between finite constraints and unbounded
        // constraints".
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pump(_afterWidthAnimation);
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // ...and back to idle.
        await tester.pumpWidget(wrap(LoadingButton(
          label: 'Créer le gazoil',
          isLoading: false,
          onPressed: () {},
          style: style,
          minHeight: 56,
        )));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Créer le gazoil'), findsOneWidget);
      });
    }

    testWidgets('never animates to an unbounded width', (tester) async {
      await tester.pumpWidget(wrap(const LoadingButton(
        label: 'Créer',
        isLoading: false,
        onPressed: null,
      )));
      await tester.pumpAndSettle();

      for (final container in tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))) {
        expect(container.constraints?.hasBoundedWidth ?? true, isTrue);
      }
      final box = tester.renderObject<RenderBox>(find.byType(ElevatedButton));
      expect(box.size.width.isFinite, isTrue);
    });

    testWidgets('shrinks while loading and expands when idle', (tester) async {
      await tester.pumpWidget(wrap(const LoadingButton(
        label: 'Créer',
        isLoading: false,
        onPressed: null,
        minHeight: 56,
      )));
      await tester.pumpAndSettle();
      final idleWidth = tester.getSize(find.byType(ElevatedButton)).width;

      await tester.pumpWidget(wrap(const LoadingButton(
        label: 'Créer',
        isLoading: true,
        onPressed: null,
        minHeight: 56,
      )));
      await tester.pump(_afterWidthAnimation);
      final loadingWidth = tester.getSize(find.byType(ElevatedButton)).width;

      expect(loadingWidth, lessThan(idleWidth));
      expect(loadingWidth, 112); // minHeight * 2
    });

    testWidgets('survives unbounded width constraints', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              LoadingButton(
                label: 'Créer',
                isLoading: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(_afterWidthAnimation);

      expect(tester.takeException(), isNull);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
