sealed class AppFailure {
  const AppFailure(this.message);
  final String message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {this.statusCode});
  final int? statusCode;
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {this.code});
  final String? code;
}

class AuthCancelledFailure extends AuthFailure {
  const AuthCancelledFailure([super.message = 'Sign-in was cancelled.']);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message);
}
