import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leguejuste/core/constants/app_constants.dart';
import 'package:leguejuste/core/theme/app_colors.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/friends/presentation/providers/friends_provider.dart';
import 'package:leguejuste/features/groups/presentation/screens/create_group_screen.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'test-user-id';
}

/// Helper to wrap the screen with necessary providers
Widget buildTestWidget({
  List<FriendEntity> friends = const [],
  bool friendsLoading = false,
}) {
  return ProviderScope(
    overrides: [
      userFriendsProvider.overrideWith((_) {
        if (friendsLoading) {
          return const Stream.empty();
        }
        return Stream.value(friends);
      }),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateProvider.overrideWith((_) => Stream.value(MockUser())),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const CreateGroupScreen(),
    ),
  );
}

void main() {
  group('CreateGroupScreen - Layout', () {
    testWidgets('renders app bar with correct title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Nouveau groupe'), findsOneWidget);
    });

    testWidgets('renders group icon picker with gradient avatar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the edit icon badge on the avatar
      expect(find.byIcon(Icons.edit), findsOneWidget);
      // Default icon should be restaurant
      expect(find.byIcon(Icons.restaurant_outlined), findsWidgets);
    });

    testWidgets('renders name field with rotating hint', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Nom du groupe'), findsOneWidget);
      // First hint should be visible
      expect(
        find.text('Ex: ${AppConstants.groupNameExamples[0]}'),
        findsOneWidget,
      );
    });

    testWidgets('hint text rotates after 3 seconds', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify initial hint
      expect(
        find.text('Ex: ${AppConstants.groupNameExamples[0]}'),
        findsOneWidget,
      );

      // Advance timer by 3 seconds
      await tester.pump(const Duration(seconds: 3));

      // Should now show second hint
      expect(
        find.text('Ex: ${AppConstants.groupNameExamples[1]}'),
        findsOneWidget,
      );
    });

    testWidgets('hint wraps around after all examples', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Advance through all examples
      for (int i = 0; i < AppConstants.groupNameExamples.length; i++) {
        await tester.pump(const Duration(seconds: 3));
      }

      // Should wrap back to first
      expect(
        find.text('Ex: ${AppConstants.groupNameExamples[0]}'),
        findsOneWidget,
      );
    });

    testWidgets('renders description field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Description (optionnel)'), findsOneWidget);
      expect(find.text('Ajoutez une description...'), findsOneWidget);
    });

    testWidgets('renders currency selector defaulting to CFA', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Devise'), findsOneWidget);
      // Default value should be CFA
      expect(find.text('CFA (FCFA)'), findsOneWidget);
      // payments icon
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    });

    testWidgets('renders "Inviter des amis" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Inviter des amis'), findsOneWidget);
    });

    testWidgets('renders QR and share action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Scanner QR'), findsOneWidget);
      expect(find.text('Partager le lien'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('renders create button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Créer le groupe'), findsOneWidget);
    });
  });

  group('CreateGroupScreen - Friends Section', () {
    testWidgets('shows empty state when no friends', (tester) async {
      await tester.pumpWidget(buildTestWidget(friends: []));
      await tester.pumpAndSettle();

      expect(
        find.text('Ajoutez des amis via le QR code pour les inviter'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('shows friend chips when friends exist', (tester) async {
      final friends = [
        FriendEntity(
          id: 'f1',
          displayName: 'Alice',
          qrCode: 'qr-1',
          addedAt: DateTime.now(),
        ),
        FriendEntity(
          id: 'f2',
          displayName: 'Bob',
          qrCode: 'qr-2',
          addedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(friends: friends));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(2));
    });

    testWidgets('friend chips toggle selection on tap', (tester) async {
      final friends = [
        FriendEntity(
          id: 'f1',
          displayName: 'Alice',
          qrCode: 'qr-1',
          addedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(friends: friends));
      await tester.pumpAndSettle();

      final chip = find.byType(FilterChip);
      expect(chip, findsOneWidget);

      // Ensure visible first
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();

      // Initially not selected
      expect(tester.widget<FilterChip>(chip).selected, isFalse);

      // Tap to select
      await tester.tap(chip);
      await tester.pumpAndSettle();

      // The chip should now be selected
      expect(tester.widget<FilterChip>(chip).selected, isTrue);

      // Tap again to deselect
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(tester.widget<FilterChip>(chip).selected, isFalse);
    });

    testWidgets('friend avatar shows first letter of name', (tester) async {
      final friends = [
        FriendEntity(
          id: 'f1',
          displayName: 'Fatou',
          qrCode: 'qr-1',
          addedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(friends: friends));
      await tester.pumpAndSettle();

      expect(find.text('F'), findsOneWidget);
    });
  });

  group('CreateGroupScreen - Icon Picker', () {
    testWidgets('tapping avatar opens icon picker bottom sheet', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the large gradient avatar container (first restaurant icon = the avatar)
      await tester.tap(find.byIcon(Icons.restaurant_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Choisir une icône'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('icon picker shows grid of icons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.restaurant_outlined).first);
      await tester.pumpAndSettle();

      // GridView should exist with icons inside it
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      // Icons specific to the grid (not on the main screen)
      final gridIcons = find.descendant(
        of: grid,
        matching: find.byType(Icon),
      );
      expect(gridIcons, findsNWidgets(AppConstants.groupIcons.length));
    });

    testWidgets('selecting an icon closes sheet and updates avatar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the icon picker
      await tester.tap(find.byIcon(Icons.restaurant_outlined).first);
      await tester.pumpAndSettle();

      // Tap the flight icon inside the grid
      final grid = find.byType(GridView);
      final flightInGrid = find.descendant(
        of: grid,
        matching: find.byIcon(Icons.flight_outlined),
      );
      await tester.tap(flightInGrid);
      await tester.pumpAndSettle();

      // Bottom sheet should be closed
      expect(find.text('Choisir une icône'), findsNothing);

      // Flight icon should now appear (avatar + prefix icon)
      expect(find.byIcon(Icons.flight_outlined), findsWidgets);
    });
  });

  group('CreateGroupScreen - Form Validation', () {
    testWidgets('shows error when name is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll to make the create button visible
      final createButton = find.text('Créer le groupe');
      await tester.ensureVisible(createButton);
      await tester.pumpAndSettle();

      // Tap create without filling name
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer un nom'), findsOneWidget);
    });

    testWidgets('shows error when name is too short', (tester) async {
      // Use a taller surface so the create button is visible
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(find.text('Le nom doit contenir au moins 2 caractères'), findsOneWidget);
    });

    testWidgets('no error when name has 2+ characters', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'AB');
      await tester.tap(find.text('Créer le groupe'));
      // Use pump() instead of pumpAndSettle() to check validation
      // immediately, before the async createGroup triggers animations
      await tester.pump();

      expect(find.text('Veuillez entrer un nom'), findsNothing);
      expect(find.text('Le nom doit contenir au moins 2 caractères'), findsNothing);
    });
  });

  group('CreateGroupScreen - Currency Selector', () {
    testWidgets('dropdown shows XOF first then EUR, USD, GBP', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.text('CFA (FCFA)'));
      await tester.pumpAndSettle();

      // All options should be visible
      expect(find.text('CFA (FCFA)'), findsWidgets); // selected + in list
      expect(find.text('Euro (\u20AC)'), findsOneWidget);
      expect(find.text('Dollar (\$)'), findsOneWidget);
      expect(find.text('Livre (\u00A3)'), findsOneWidget);
    });
  });
}
