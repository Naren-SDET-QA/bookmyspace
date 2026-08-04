import 'dart:async';

import 'package:bookmyspace/features/auth/domain/auth_repository.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';

/// In-memory mock used for unit tests and widget tests.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({AuthUser? initialUser}) : _user = initialUser {
    _controller = StreamController<AuthUser?>.broadcast();
  }

  AuthUser? _user;
  late final StreamController<AuthUser?> _controller;

  /// Overridable behaviours for test scenarios.
  bool failSignIn = false;
  bool failVerify = false;
  bool failSignOut = false;
  int signInCount = 0;
  int verifyCount = 0;
  AppAccessRole accessRole = AppAccessRole.customer;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signInWithApple() => _signIn();

  @override
  Future<AuthUser> signInWithGoogle() => _signIn();

  @override
  Future<void> signInWithEmailOtp(String email) async {
    signInCount++;
    if (failSignIn) {
      throw Exception('OTP send failed');
    }
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    signInCount++;
    if (failSignIn) {
      throw Exception('OTP send failed');
    }
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    signInCount++;
    if (failSignIn) throw Exception('Confirmation resend failed');
  }

  @override
  Future<AuthUser> signInWithPassword(String email, String password) async {
    signInCount++;
    if (failSignIn) throw Exception('Development login failed');
    _user = AuthUser(id: 'mock-user', email: email, fullName: 'Test User');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppAccessRole> resolveAccessRole() async => accessRole;

  Future<AuthUser> _signIn() async {
    signInCount++;
    if (failSignIn) {
      throw Exception('Social sign-in failed');
    }
    _user = const AuthUser(
      id: 'mock-user',
      email: 'mock@test.com',
      fullName: 'Mock User',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> verifyEmailOtp(String email, String token) async {
    verifyCount++;
    if (failVerify) {
      throw Exception('Invalid OTP');
    }
    _user = AuthUser(id: 'mock-user', email: email, fullName: 'Mock User');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> verifyPhoneOtp(String phone, String token) =>
      verifyEmailOtp('', token);

  @override
  Future<void> signOut() async {
    if (failSignOut) {
      throw Exception('Sign out failed');
    }
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signOutAllDevices() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> refreshSession() async {}

  void restoreSession(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();
}
