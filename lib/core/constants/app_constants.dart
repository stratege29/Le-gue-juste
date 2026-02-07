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
  static const String defaultCurrency = 'EUR';
  static const Map<String, String> currencySymbols = {
    'EUR': '\u20AC',
    'USD': '\$',
    'GBP': '\u00A3',
    'XOF': 'CFA',
    'XAF': 'CFA',
  };

  // Balance threshold (for considering as settled)
  static const double balanceThreshold = 0.01;
}
