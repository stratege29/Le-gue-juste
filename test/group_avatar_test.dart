import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/constants/app_constants.dart';
import 'package:leguejuste/core/widgets/group_avatar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('GroupAvatar - icon: sentinel', () {
    testWidgets('renders the matching Material icon instead of a network image',
        (tester) async {
      await tester.pumpWidget(wrap(const GroupAvatar(imageUrl: 'icon:restaurant')));
      await tester.pumpAndSettle();

      // Regression: 'icon:restaurant' used to reach Image.network and throw
      // "Invalid argument(s): No host specified in URI icon:restaurant".
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(AppConstants.groupIcons['restaurant']!), findsOneWidget);
    });

    testWidgets('falls back to a generic icon for an unknown key',
        (tester) async {
      await tester.pumpWidget(wrap(const GroupAvatar(imageUrl: 'icon:unknown_key')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('renders a generic icon when imageUrl is null', (tester) async {
      await tester.pumpWidget(wrap(const GroupAvatar(imageUrl: null)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('renders a generic icon for a legacy non-URL value',
        (tester) async {
      // Groups already stored in Firestore may hold arbitrary junk.
      await tester.pumpWidget(wrap(const GroupAvatar(imageUrl: 'restaurant')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('uses Image.network for a real http(s) url', (tester) async {
      await tester.pumpWidget(
          wrap(const GroupAvatar(imageUrl: 'https://example.com/group.png')));

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('GroupAvatar.iconFor', () {
    test('maps every icon key stored by the create screen', () {
      for (final entry in AppConstants.groupIcons.entries) {
        expect(GroupAvatar.iconFor('icon:${entry.key}'), entry.value);
      }
    });

    test('returns null for non-sentinel values', () {
      expect(GroupAvatar.iconFor(null), isNull);
      expect(GroupAvatar.iconFor(''), isNull);
      expect(GroupAvatar.iconFor('https://example.com/a.png'), isNull);
    });

    test('falls back to a generic icon for an unknown key', () {
      expect(GroupAvatar.iconFor('icon:nope'), Icons.group);
    });
  });

  group('GroupAvatar.isNetworkImage', () {
    test('accepts http and https urls only', () {
      expect(GroupAvatar.isNetworkImage('https://example.com/a.png'), isTrue);
      expect(GroupAvatar.isNetworkImage('http://example.com/a.png'), isTrue);
      expect(GroupAvatar.isNetworkImage('icon:restaurant'), isFalse);
      expect(GroupAvatar.isNetworkImage('emoji:🍔'), isFalse);
      expect(GroupAvatar.isNetworkImage('gs://bucket/a.png'), isFalse);
      expect(GroupAvatar.isNetworkImage(''), isFalse);
      expect(GroupAvatar.isNetworkImage(null), isFalse);
    });
  });
}
