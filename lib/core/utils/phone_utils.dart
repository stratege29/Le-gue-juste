class PhoneUtils {
  PhoneUtils._();

  /// Normalizes a raw phone number to E.164 format.
  ///
  /// Handles formats like:
  /// - `+225XXXXXXXX` (already international)
  /// - `00225XXXXXXXX` (international with 00 prefix)
  /// - `07XXXXXXXX` (local, needs country code)
  ///
  /// Returns null if the number cannot be normalized.
  static String? normalize(String rawNumber, {String defaultCountryCode = '+225'}) {
    // Strip spaces, dashes, parentheses, dots
    var cleaned = rawNumber.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    if (cleaned.isEmpty) return null;

    // Already in E.164 format
    if (cleaned.startsWith('+')) {
      return cleaned.length >= 8 ? cleaned : null;
    }

    // International with 00 prefix
    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
      return cleaned.length >= 8 ? cleaned : null;
    }

    // Local number — prepend default country code
    // Remove leading 0 if present (common in local formats)
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Ensure the default country code starts with +
    final countryCode = defaultCountryCode.startsWith('+')
        ? defaultCountryCode
        : '+$defaultCountryCode';

    final result = '$countryCode$cleaned';
    return result.length >= 8 ? result : null;
  }
}
