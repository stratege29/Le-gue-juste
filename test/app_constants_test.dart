import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/constants/app_constants.dart';

void main() {
  group('AppConstants.groupNameExamples', () {
    test('contains 8 examples', () {
      expect(AppConstants.groupNameExamples.length, 8);
    });

    test('all examples are non-empty strings', () {
      for (final example in AppConstants.groupNameExamples) {
        expect(example.isNotEmpty, isTrue, reason: 'Example should not be empty');
      }
    });

    test('contains Ivorian-market examples', () {
      final joined = AppConstants.groupNameExamples.join(' ');
      expect(joined.contains('Marcory'), isTrue);
      expect(joined.contains('Dakar'), isTrue);
      expect(joined.contains('Cocody'), isTrue);
      expect(joined.contains('Bassam'), isTrue);
    });

    test('has no duplicates', () {
      final unique = AppConstants.groupNameExamples.toSet();
      expect(unique.length, AppConstants.groupNameExamples.length);
    });
  });

  group('AppConstants.groupIcons', () {
    test('contains 20 icons', () {
      expect(AppConstants.groupIcons.length, 20);
    });

    test('all keys are non-empty strings', () {
      for (final key in AppConstants.groupIcons.keys) {
        expect(key.isNotEmpty, isTrue, reason: 'Key "$key" should not be empty');
      }
    });

    test('all values are valid IconData', () {
      for (final entry in AppConstants.groupIcons.entries) {
        expect(entry.value, isA<IconData>(),
            reason: 'Icon for "${entry.key}" should be IconData');
      }
    });

    test('contains essential category icons', () {
      expect(AppConstants.groupIcons.containsKey('restaurant'), isTrue);
      expect(AppConstants.groupIcons.containsKey('flight'), isTrue);
      expect(AppConstants.groupIcons.containsKey('home'), isTrue);
      expect(AppConstants.groupIcons.containsKey('shopping_cart'), isTrue);
      expect(AppConstants.groupIcons.containsKey('local_gas_station'), isTrue);
      expect(AppConstants.groupIcons.containsKey('directions_car'), isTrue);
    });

    test('contains a fallback "more" icon', () {
      expect(AppConstants.groupIcons.containsKey('more_horiz'), isTrue);
    });

    test('default currency is XOF', () {
      expect(AppConstants.defaultCurrency, 'XOF');
    });
  });
}
