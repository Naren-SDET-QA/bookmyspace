import 'auth_user.dart';

/// Authentication state used across the application.
///
/// NOTE: Freezed codegen is configured but was not run in this environment;
/// this sealed-by-convention state is hand-written.
sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});
  final AuthUser user;
}

class AuthLoading extends AuthState {
  const AuthLoading();
}
