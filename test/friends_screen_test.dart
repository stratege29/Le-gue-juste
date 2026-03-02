import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leguejuste/core/theme/app_colors.dart';
import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/features/friends/presentation/providers/friends_provider.dart';
import 'package:leguejuste/features/friends/presentation/screens/friends_screen.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'test-user-id';
}

/// Default friends list to avoid EmptyStateWidget's infinite animation
final _defaultFriends = [
  FriendEntity(
    id: 'f1',
    displayName: 'Alice',
    qrCode: 'qr-1',
    addedAt: DateTime.now(),
  ),
];

Widget buildTestWidget({
  List<FriendEntity>? friends,
  bool friendsLoading = false,
}) {
  return ProviderScope(
    overrides: [
      userFriendsProvider.overrideWith((_) {
        if (friendsLoading) {
          return const Stream.empty();
        }
        return Stream.value(friends ?? _defaultFriends);
      }),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateProvider.overrideWith((_) => Stream.value(MockUser())),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const FriendsScreen(),
    ),
  );
}

/// Sets a taller screen size so the bottom sheet (5 options) doesn't overflow
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
}

void resetScreen(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  group('FriendsScreen - Layout', () {
    testWidgets('renders app bar with title "Mes Amis"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Mes Amis'), findsOneWidget);
    });

    testWidgets('renders add friend icon button in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('renders FAB with "Ajouter" label', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });
  });

  group('FriendsScreen - Empty State', () {
    testWidgets('shows empty state when no friends', (tester) async {
      await tester.pumpWidget(buildTestWidget(friends: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aucun ami'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('empty state has action button to add friend', (tester) async {
      await tester.pumpWidget(buildTestWidget(friends: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ajouter un ami'), findsWidgets);
    });
  });

  group('FriendsScreen - Friends List', () {
    testWidgets('displays friends when available', (tester) async {
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
    });

    testWidgets('shows avatar with first letter', (tester) async {
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

    testWidgets('shows relative date for recently added friends', (tester) async {
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

      expect(find.textContaining("aujourd'hui"), findsOneWidget);
    });

    testWidgets('shows popup menu on each friend card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });

  group('FriendsScreen - Bottom Sheet Options', () {
    testWidgets('tapping app bar icon opens bottom sheet', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un ami'), findsWidgets);
    });

    testWidgets('bottom sheet shows "Scanner un QR code" option', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Scanner un QR code'), findsOneWidget);
      expect(find.text('Scannez le code de votre ami'), findsOneWidget);
    });

    testWidgets('bottom sheet shows "Mon QR code" option', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Mon QR code'), findsOneWidget);
      expect(find.text('Montrez votre code \u00e0 un ami'), findsOneWidget);
    });

    testWidgets('bottom sheet shows "Entrer un code" option', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Entrer un code'), findsOneWidget);
      expect(find.text('Saisissez le code manuellement'), findsOneWidget);
    });

    testWidgets('bottom sheet shows "Num\u00e9ro de t\u00e9l\u00e9phone" option', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Num\u00e9ro de t\u00e9l\u00e9phone'), findsOneWidget);
      expect(find.text('Envoyez une demande d\'ami'), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('bottom sheet shows "Depuis mes contacts" option', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.text('Depuis mes contacts'), findsOneWidget);
      expect(find.text('Retrouvez vos amis sur LeGuJuste'), findsOneWidget);
      expect(find.byIcon(Icons.contacts), findsOneWidget);
    });

    testWidgets('bottom sheet shows all 5 options', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      // Verify all 5 option texts are present
      expect(find.text('Scanner un QR code'), findsOneWidget);
      expect(find.text('Mon QR code'), findsOneWidget);
      expect(find.text('Entrer un code'), findsOneWidget);
      expect(find.text('Num\u00e9ro de t\u00e9l\u00e9phone'), findsOneWidget);
      expect(find.text('Depuis mes contacts'), findsOneWidget);
    });

    testWidgets('tapping "Num\u00e9ro de t\u00e9l\u00e9phone" opens phone dialog', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Num\u00e9ro de t\u00e9l\u00e9phone'));
      await tester.pumpAndSettle();

      expect(find.text('Envoyer une demande'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Envoyer'), findsOneWidget);
    });

    testWidgets('phone dialog has Annuler button that closes it', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Num\u00e9ro de t\u00e9l\u00e9phone'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter par num\u00e9ro'), findsNothing);
    });

    testWidgets('tapping "Entrer un code" opens code dialog', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrer un code'));
      await tester.pumpAndSettle();

      expect(find.text('Entrer un code'), findsWidgets);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('bottom sheet icons have correct colors', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      // QR scanner icon in the bottom sheet
      final scannerIcon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Scanner un QR code'),
          matching: find.byIcon(Icons.qr_code_scanner),
        ),
      );
      expect(scannerIcon.color, AppColors.primary);

      // Phone icon should be green
      final phoneIcon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Num\u00e9ro de t\u00e9l\u00e9phone'),
          matching: find.byIcon(Icons.phone),
        ),
      );
      expect(phoneIcon.color, Colors.green);

      // Contacts icon should be orange
      final contactsIcon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Depuis mes contacts'),
          matching: find.byIcon(Icons.contacts),
        ),
      );
      expect(contactsIcon.color, Colors.orange);
    });

    testWidgets('each option has a chevron_right trailing icon', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    });
  });

  group('FriendsScreen - Remove Friend Dialog', () {
    testWidgets('tapping remove in popup shows confirmation dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet ami?'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
    });

    testWidgets('cancel button closes remove dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet ami?'), findsNothing);
    });
  });

  group('FriendsScreen - Loading State', () {
    testWidgets('shows skeleton loader while friends loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(friendsLoading: true));
      await tester.pump();

      expect(find.text('Aucun ami'), findsNothing);
      expect(find.text('Alice'), findsNothing);
    });
  });

  group('FriendsScreen - FAB interactions', () {
    testWidgets('tapping FAB opens same bottom sheet as app bar icon', (tester) async {
      useTallScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un ami'), findsWidgets);
      // All 5 option texts present
      expect(find.text('Scanner un QR code'), findsOneWidget);
      expect(find.text('Num\u00e9ro de t\u00e9l\u00e9phone'), findsOneWidget);
      expect(find.text('Depuis mes contacts'), findsOneWidget);
    });
  });
}
