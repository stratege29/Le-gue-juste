import 'package:equatable/equatable.dart';

/// Base failure class for the app
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server/Network failures
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred'])
      : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection'])
      : super(message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'Connection timed out'])
      : super(message);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
      : super('Invalid credentials', code: 'invalid-credentials');
}

class UnauthorizedFailure extends AuthFailure {
  const UnauthorizedFailure()
      : super('Unauthorized access', code: 'unauthorized');
}

/// Cache failures
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred']) : super(message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found'])
      : super(message);
}

/// Permission failure
class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permission denied'])
      : super(message);
}

/// Unknown failure
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unexpected error occurred'])
      : super(message);
}
