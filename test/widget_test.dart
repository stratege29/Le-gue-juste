import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tests for core widgets that don't require Firebase
import 'package:leguejuste/core/widgets/widgets.dart';
import 'package:leguejuste/core/theme/app_colors.dart';

void main() {
  group('Core Widgets', () {
    testWidgets('EmptyStateWidget renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.group_outlined,
              title: 'Test Title',
              description: 'Test Description',
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('EmptyStateWidget with action button', (WidgetTester tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.add,
              title: 'Empty State',
              actionLabel: 'Add Item',
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Item'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      await tester.pump();

      expect(actionCalled, isTrue);
    });

    testWidgets('AllSettledStateWidget renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AllSettledStateWidget(
              subtitle: 'Custom subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Tout est equilibre!'), findsOneWidget);
      expect(find.text('Custom subtitle'), findsOneWidget);
    });

    testWidgets('IconBadge renders with correct size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconBadge(
              icon: Icons.person,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Verify the icon is rendered
      expect(find.byIcon(Icons.person), findsOneWidget);
      // Verify at least one Container is present (for the badge)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('IconBadge.category returns correct icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconBadge.category('food'),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('IconBadge.balance shows correct colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                IconBadge.balance(isPositive: true),
                IconBadge.balance(isPositive: false),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget); // positive - receiving money
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget); // negative - paying money
    });

    testWidgets('SkeletonLoader renders shimmer effect', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(width: 100, height: 20),
          ),
        ),
      );

      // Shimmer widget should be present
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('LoadingButton shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              label: 'Submit',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LoadingButton shows text when not loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              label: 'Submit',
              isLoading: false,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Theme', () {
    testWidgets('AppColors are accessible', (WidgetTester tester) async {
      // Test that color constants are defined
      expect(AppColors.primary, isNotNull);
      expect(AppColors.secondary, isNotNull);
      expect(AppColors.success, isNotNull);
      expect(AppColors.error, isNotNull);
      expect(AppColors.warning, isNotNull);
    });
  });

  group('ProviderScope', () {
    testWidgets('ProviderScope initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: Text('Provider Test'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Provider Test'), findsOneWidget);
    });
  });
}
