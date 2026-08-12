import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize - Côte d\'Ivoire (default country)', () {
    test('keeps the leading 0 of a national number', () {
      expect(PhoneUtils.normalize('0102030405'), '+2250102030405');
      expect(PhoneUtils.normalize('0712345678'), '+2250712345678');
    });

    test('ignores spaces, dots, dashes and parentheses', () {
      expect(PhoneUtils.normalize('01 02 03 04 05'), '+2250102030405');
      expect(PhoneUtils.normalize('01.02.03.04.05'), '+2250102030405');
      expect(PhoneUtils.normalize('01-02-03-04-05'), '+2250102030405');
      expect(PhoneUtils.normalize('(01) 02 03 04 05'), '+2250102030405');
      expect(PhoneUtils.normalize(' +225 01 02 03 04 05 '), '+2250102030405');
    });

    test('accepts the dial code with or without +', () {
      expect(PhoneUtils.normalize('+2250102030405'), '+2250102030405');
      expect(PhoneUtils.normalize('2250102030405'), '+2250102030405');
      expect(PhoneUtils.normalize('225 01 02 03 04 05'), '+2250102030405');
    });

    test('converts a leading 00 to +', () {
      expect(PhoneUtils.normalize('00225 0102030405'), '+2250102030405');
      expect(PhoneUtils.normalize('002250102030405'), '+2250102030405');
    });

    test('matches the E.164 format Firebase Auth stores', () {
      // users/{uid}.phoneNumber is written from user.phoneNumber verbatim.
      const fromFirebaseAuth = '+2250102030405';
      expect(PhoneUtils.normalize('01 02 03 04 05'), fromFirebaseAuth);
    });
  });

  group('PhoneUtils.normalize - international numbers', () {
    test('keeps already normalized numbers untouched', () {
      expect(PhoneUtils.normalize('+33612345678'), '+33612345678');
      expect(PhoneUtils.normalize('+221771234567'), '+221771234567');
      expect(PhoneUtils.normalize('+22370123456'), '+22370123456');
      expect(PhoneUtils.normalize('+22670123456'), '+22670123456');
      expect(PhoneUtils.normalize('+22890123456'), '+22890123456');
    });

    test('drops the trunk 0 written after a dial code', () {
      expect(PhoneUtils.normalize('+33 (0)6 12 34 56 78'), '+33612345678');
      expect(PhoneUtils.normalize('+33 0612345678'), '+33612345678');
      expect(PhoneUtils.normalize('0033 (0)612345678'), '+33612345678');
    });

    test('never drops the significant leading 0 of an Ivorian number', () {
      expect(PhoneUtils.normalize('+225 (0)1 02 03 04 05'), '+2250102030405');
      expect(PhoneUtils.normalize('+225 0102030405'), '+2250102030405');
    });

    test('keeps numbers whose bundled numbering plan is outdated', () {
      // Benin moved to 10-digit numbers in 2022; countries.dart still says 8.
      expect(PhoneUtils.normalize('+2290112345678'), '+2290112345678');
    });
  });

  group('PhoneUtils.normalize - other default countries', () {
    test('strips the French trunk 0', () {
      expect(
        PhoneUtils.normalize('06 12 34 56 78', defaultCountryCode: 'FR'),
        '+33612345678',
      );
    });

    test('handles a Senegalese national number', () {
      expect(
        PhoneUtils.normalize('77 123 45 67', defaultCountryCode: 'SN'),
        '+221771234567',
      );
    });

    test('is case insensitive on the ISO code', () {
      expect(
        PhoneUtils.normalize('0612345678', defaultCountryCode: 'fr'),
        '+33612345678',
      );
    });

    test('throws on an unknown ISO code', () {
      expect(
        () => PhoneUtils.normalize('0102030405', defaultCountryCode: 'XX'),
        throwsArgumentError,
      );
    });
  });

  group('PhoneUtils.normalize - rejected input', () {
    test('returns null for empty or digitless input', () {
      expect(PhoneUtils.normalize(''), isNull);
      expect(PhoneUtils.normalize('   '), isNull);
      expect(PhoneUtils.normalize('N/A'), isNull);
    });

    test('returns null for short codes and service numbers', () {
      expect(PhoneUtils.normalize('114'), isNull);
      expect(PhoneUtils.normalize('1234'), isNull);
      expect(PhoneUtils.normalize('#123#'), isNull);
    });

    test('returns null for numbers that are too short or too long', () {
      expect(PhoneUtils.normalize('01020304'), isNull); // legacy 8-digit CI
      expect(PhoneUtils.normalize('+1234567'), isNull);
      expect(PhoneUtils.normalize('+1234567890123456'), isNull);
    });
  });

  group('PhoneUtils.normalize - deduplication', () {
    test('collapses the ways a single number can be written', () {
      final variants = [
        '0102030405',
        '01 02 03 04 05',
        '+225 01 02 03 04 05',
        '00225 01.02.03.04.05',
        '(+225) 0102030405',
      ];
      final normalized = variants.map(PhoneUtils.normalize).toSet();
      expect(normalized, {'+2250102030405'});
    });
  });
}
