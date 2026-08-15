import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/utils/image_url.dart';
import 'package:leguejuste/core/widgets/emoji_avatar.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

CircleAvatar avatarOf(WidgetTester tester) =>
    tester.widget<CircleAvatar>(find.byType(CircleAvatar));

void main() {
  group('EmojiAvatar', () {
    testWidgets('renders the emoji for an emoji: sentinel', (tester) async {
      await tester.pumpWidget(wrap(const EmojiAvatar(avatarUrl: 'emoji:🍔')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('🍔'), findsOneWidget);
      expect(avatarOf(tester).backgroundImage, isNull);
    });

    testWidgets('falls back to the person icon for a non-URL value',
        (tester) async {
      // Regression: any non-empty value used to reach NetworkImage and throw
      // "Invalid argument(s): No host specified in URI ...".
      await tester.pumpWidget(wrap(const EmojiAvatar(avatarUrl: 'icon:person')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(avatarOf(tester).backgroundImage, isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('falls back to the person icon for a non-http scheme',
        (tester) async {
      await tester
          .pumpWidget(wrap(const EmojiAvatar(avatarUrl: 'gs://bucket/a.png')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(avatarOf(tester).backgroundImage, isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders the person icon when avatarUrl is null',
        (tester) async {
      await tester.pumpWidget(wrap(const EmojiAvatar(avatarUrl: null)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('uses a NetworkImage for a real http(s) url', (tester) async {
      await tester.pumpWidget(
          wrap(const EmojiAvatar(avatarUrl: 'https://example.com/me.png')));

      expect(avatarOf(tester).backgroundImage, isA<NetworkImage>());
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  group('isNetworkImageUrl', () {
    test('accepts http and https urls only', () {
      expect(isNetworkImageUrl('https://example.com/a.png'), isTrue);
      expect(isNetworkImageUrl('http://example.com/a.png'), isTrue);
      expect(isNetworkImageUrl('icon:restaurant'), isFalse);
      expect(isNetworkImageUrl('emoji:🍔'), isFalse);
      expect(isNetworkImageUrl('gs://bucket/a.png'), isFalse);
      expect(isNetworkImageUrl('https://'), isFalse);
      expect(isNetworkImageUrl('/local/path.png'), isFalse);
      expect(isNetworkImageUrl(''), isFalse);
      expect(isNetworkImageUrl(null), isFalse);
    });
  });
}
