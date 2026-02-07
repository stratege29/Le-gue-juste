class RouteConstants {
  RouteConstants._();

  // Auth routes
  static const String splash = '/';
  static const String phoneInput = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile-setup';

  // Main routes
  static const String home = '/home';
  static const String groups = '/groups';
  static const String groupDetail = '/groups/:groupId';
  static const String createGroup = '/groups/create';
  static const String groupSettings = '/groups/:groupId/settings';

  // Expense routes
  static const String addExpense = '/groups/:groupId/expense/add';
  static const String expenseDetail = '/groups/:groupId/expense/:expenseId';

  // Balance routes
  static const String balances = '/balances';
  static const String settleUp = '/groups/:groupId/settle';

  // Profile routes
  static const String profile = '/profile';
  static const String myQrCode = '/profile/qr';
  static const String scanQr = '/scan';
  static const String friends = '/friends';
  static const String settings = '/profile/settings';
  static const String notifications = '/notifications';

  // Activity routes
  static const String activity = '/activity';
}
