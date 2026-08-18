import '../domain/auth_user.dart';

/// Authentication contract.
///
/// The implementation lives behind this interface so Supabase (or any future
/// provider) can be swapped without touching presentation code.
abstract interface class AuthRepository {
  /// Streams of authentication state changes.
  Stream<AuthUser?> authStateChanges();

  /// Currently signed-in user, if any.
  AuthUser? get currentUser;

  /// Signs in with an email OTP.
  Future<void> signInWithEmailOtp(String email);

  /// Verifies an email OTP token.
  Future<AuthUser> verifyEmailOtp(String email, String token);

  /// Signs in with a phone OTP.
  Future<void> signInWithPhoneOtp(String phone);

  /// Verifies a phone OTP token.
  Future<AuthUser> verifyPhoneOtp(String phone, String token);

  /// Signs in with Google.
  Future<AuthUser> signInWithGoogle();

  /// Signs in with Apple.
  Future<AuthUser> signInWithApple();

  /// Signs out of the current device.
  Future<void> signOut();

  /// Signs out of every device for the current user.
  Future<void> signOutAllDevices();

  /// Deletes the current user's account and all data.
  Future<void> deleteAccount();

  /// Updates display name and avatar URL directly in the user profile.
  Future<AuthUser> updateProfile({String? fullName, String? avatarUrl});

  /// Refreshes the session if it is close to expiry.
  Future<void> refreshSession();
}
