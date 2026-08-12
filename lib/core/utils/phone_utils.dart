import 'package:intl_phone_field/countries.dart';

/// Utilities for turning free-form phone numbers into the canonical format
/// stored on user documents in Firestore.
///
/// Firebase Auth exposes `user.phoneNumber` in E.164 (`+2250102030405`) and
/// that value is written verbatim to `users/{uid}.phoneNumber`
/// (see `AuthNotifier.createProfile`). Lookups are exact string comparisons
/// (`whereIn` / `isEqualTo`), so any number compared against Firestore must go
/// through [normalize] first.
///
/// Usage:
/// ```dart
/// PhoneUtils.normalize('01 02 03 04 05');      // +2250102030405
/// PhoneUtils.normalize('00225 01.02.03.04.05') // +2250102030405
/// PhoneUtils.normalize('+33 (0)6 12 34 56 78') // +33612345678
/// PhoneUtils.normalize('114');                 // null
/// ```
class PhoneUtils {
  PhoneUtils._();

  /// ISO code assumed when a number carries no international prefix.
  ///
  /// Matches the `initialCountryCode: 'CI'` of the app's `IntlPhoneField`
  /// inputs.
  static const String defaultCountry = 'CI';

  /// E.164 allows at most 15 digits, and nothing shorter than 8 is a real
  /// international number (short codes and service numbers are 3-6 digits).
  static const int _minDigits = 8;
  static const int _maxDigits = 15;

  /// Normalizes [rawNumber] to E.164 (a `+` followed by digits only), or
  /// returns `null` when it cannot be read as a dialable number.
  ///
  /// Spaces, dots, dashes and parentheses are ignored, and a leading `00` is
  /// treated as `+`. Numbers without an international prefix are assumed to
  /// belong to [defaultCountryCode] and are only accepted when their length
  /// fits that country's numbering plan — either as-is (Ivorian numbers keep
  /// their leading `0`: `0102030405` -> `+2250102030405`) or after dropping a
  /// national trunk `0` (French numbers: `0612345678` -> `+33612345678`).
  static String? normalize(
    String rawNumber, {
    String defaultCountryCode = defaultCountry,
  }) {
    final digits = _digitsOf(rawNumber);
    if (digits.isEmpty) return null;

    if (rawNumber.trimLeft().startsWith('+') || digits.startsWith('00')) {
      final international = digits.replaceFirst(RegExp(r'^0{2}'), '');
      if (international.length < _minDigits ||
          international.length > _maxDigits) {
        return null;
      }
      return '+${_withoutTrunkZero(international)}';
    }

    final country = _countryByIsoCode(defaultCountryCode);
    final dialCode = country.fullCountryCode;

    // Already carries the country's dial code, only the `+` is missing.
    if (digits.startsWith(dialCode) &&
        _hasNationalLength(country, digits.length - dialCode.length)) {
      return '+$digits';
    }

    // Plain national number (Ivorian numbers keep their leading `0`).
    if (_hasNationalLength(country, digits.length)) {
      return '+$dialCode$digits';
    }

    // National number written with a trunk prefix (France, Belgium, ...).
    if (digits.startsWith('0') &&
        _hasNationalLength(country, digits.length - 1)) {
      return '+$dialCode${digits.substring(1)}';
    }

    return null;
  }

  static String _digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Drops the national trunk `0` some contacts keep after the dial code
  /// (`+33 (0)6 ...`), but only when doing so is what makes the number fit a
  /// numbering plan. Ivorian numbers need their leading `0`, and they already
  /// fit their plan with it, so this never strips it.
  static String _withoutTrunkZero(String digits) {
    if (_fitsAnyPlan(digits)) return digits;

    for (final country in countries) {
      final dialCode = country.fullCountryCode;
      if (!digits.startsWith('${dialCode}0')) continue;
      final national = digits.substring(dialCode.length + 1);
      if (_hasNationalLength(country, national.length)) {
        return '$dialCode$national';
      }
    }
    return digits;
  }

  static bool _fitsAnyPlan(String digits) {
    for (final country in countries) {
      final dialCode = country.fullCountryCode;
      if (digits.startsWith(dialCode) &&
          _hasNationalLength(country, digits.length - dialCode.length)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasNationalLength(Country country, int length) =>
      length >= country.minLength && length <= country.maxLength;

  static Country _countryByIsoCode(String isoCode) {
    final code = isoCode.toUpperCase();
    return countries.firstWhere(
      (country) => country.code == code,
      orElse: () => throw ArgumentError.value(
        isoCode,
        'defaultCountryCode',
        'Unknown ISO country code',
      ),
    );
  }
}
