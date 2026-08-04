import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'supabase_auth_repository.dart' show AppAuthException;

/// Offline authentication used only when Supabase keys are not configured.
class DemoAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {}

  @override
  Future<void> signInWithPhoneOtp(String phone) async {}

  @override
  Future<AuthUser> verifyEmailOtp(String email, String token) =>
      _verify(token, email: email);

  @override
  Future<AuthUser> signInWithPassword(String email, String password) =>
      _signIn(email: email, fullName: 'Development Test User');

  @override
  Future<AppAccessRole> resolveAccessRole() async => AppAccessRole.customer;

  @override
  Future<void> resendSignupConfirmation(String email) async {}

  @override
  Future<AuthUser> verifyPhoneOtp(String phone, String token) =>
      _verify(token, phone: phone);

  Future<AuthUser> _verify(
    String token, {
    String email = '',
    String phone = '',
  }) async {
    if (token != '123456') {
      throw const AppAuthException('Demo OTP is 123456.');
    }
    return _signIn(email: email, phone: phone);
  }

  @override
  Future<AuthUser> signInWithGoogle() =>
      _signIn(email: 'demo@bookmyspace.app', fullName: 'Demo User');

  @override
  Future<AuthUser> signInWithApple() =>
      _signIn(email: 'apple-demo@bookmyspace.app', fullName: 'Demo User');

  Future<AuthUser> _signIn({
    String email = '',
    String phone = '',
    String fullName = 'Guest User',
  }) async {
    _user = AuthUser(
      id: 'demo-user',
      email: email,
      phone: phone,
      fullName: fullName,
    );
    _changes.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }

  @override
  Future<void> signOutAllDevices() => signOut();

  @override
  Future<void> deleteAccount() => signOut();

  @override
  Future<void> refreshSession() async {}
}
