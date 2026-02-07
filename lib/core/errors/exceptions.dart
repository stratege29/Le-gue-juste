/// Base exception class for the app
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Server/Network exceptions
class ServerException extends AppException {
  const ServerException([String message = 'Server error occurred'])
      : super(message);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection'])
      : super(message);
}

class TimeoutException extends AppException {
  const TimeoutException([String message = 'Connection timed out'])
      : super(message);
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class InvalidPhoneNumberException extends AuthException {
  const InvalidPhoneNumberException()
      : super('Invalid phone number', code: 'invalid-phone-number');
}

class InvalidOtpException extends AuthException {
  const InvalidOtpException()
      : super('Invalid verification code', code: 'invalid-otp');
}

class OtpExpiredException extends AuthException {
  const OtpExpiredException()
      : super('Verification code expired', code: 'otp-expired');
}

class TooManyRequestsException extends AuthException {
  const TooManyRequestsException()
      : super('Too many requests. Please try again later.',
            code: 'too-many-requests');
}

class QuotaExceededException extends AuthException {
  const QuotaExceededException()
      : super('SMS quota exceeded', code: 'quota-exceeded');
}

class UserNotFoundException extends AuthException {
  const UserNotFoundException()
      : super('User not found', code: 'user-not-found');
}

class UserDisabledException extends AuthException {
  const UserDisabledException()
      : super('User account is disabled', code: 'user-disabled');
}

/// Cache exceptions
class CacheException extends AppException {
  const CacheException([String message = 'Cache error occurred'])
      : super(message);
}

class CacheNotFoundException extends CacheException {
  const CacheNotFoundException([String message = 'Data not found in cache'])
      : super(message);
}

/// QR Code exceptions
class QrCodeException extends AppException {
  const QrCodeException(super.message, {super.code});
}

class InvalidQrCodeException extends QrCodeException {
  const InvalidQrCodeException([String message = 'Invalid QR code'])
      : super(message, code: 'invalid-qr');
}

class ExpiredQrCodeException extends QrCodeException {
  const ExpiredQrCodeException([String message = 'QR code has expired'])
      : super(message, code: 'expired-qr');
}

/// Validation exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// Permission exceptions
class PermissionException extends AppException {
  const PermissionException(
      [String message = 'Permission denied', String? code])
      : super(message, code: code);
}

class CameraPermissionException extends PermissionException {
  const CameraPermissionException()
      : super('Camera permission denied', 'camera-permission-denied');
}
