class AppConstants {
  AppConstants._();

  static const String appName = 'LeGuJuste';
  static const String appVersion = '1.0.0';

  // QR Code prefix
  static const String qrCodePrefix = 'LGJ';

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;

  // OTP
  static const int otpLength = 6;
  static const int otpResendTimeout = 60; // seconds

  // Pagination
  static const int defaultPageSize = 20;

  // Currency
  static const String defaultCurrency = 'XOF';
  static const Map<String, String> currencySymbols = {
    'EUR': '\u20AC',
    'USD': '\$',
    'GBP': '\u00A3',
    'XOF': 'CFA',
    'XAF': 'CFA',
  };

  // Avatar emojis
  static const List<String> avatarEmojis = [
    '\u{1F60A}', // smiling face
    '\u{1F60E}', // sunglasses
    '\u{1F981}', // lion
    '\u{2B50}',  // star
    '\u{2764}\u{FE0F}',  // heart
    '\u{1F451}', // crown
    '\u{1F525}', // fire
    '\u{1F680}', // rocket
    '\u{1F308}', // rainbow
    '\u{2728}',  // sparkles
  ];

  // Balance threshold (for considering as settled)
  static const double balanceThreshold = 0.01;
}
