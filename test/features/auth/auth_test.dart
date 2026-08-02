import 'package:bookmyspace/features/auth/domain/auth_state.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

void main() {
  group('AuthUser', () {
    test('serializes and deserializes', () {
      const user = AuthUser(
        id: 'u1',
        email: 'a@b.com',
        phone: '9999999999',
        fullName: 'Alice',
        avatarUrl: 'https://img/avatar.png',
      );
      final json = user.toJson();
      final restored = AuthUser.fromJson(json);
      expect(restored.id, 'u1');
      expect(restored.fullName, 'Alice');
    });

    test('copyWith preserves unset fields', () {
      const user = AuthUser(id: 'u1', email: 'a@b.com');
      final updated = user.copyWith(fullName: 'Bob');
      expect(updated.email, 'a@b.com');
      expect(updated.fullName, 'Bob');
    });

    test('equality is id and email based', () {
      const a = AuthUser(id: 'u1', email: 'x@y.com');
      const b = AuthUser(id: 'u1', email: 'x@y.com', fullName: 'diff');
      expect(a, b);
    });
  });

  group('AuthState', () {
    test('discriminates state types', () {
      const unauth = AuthUnauthenticated();
      const auth = AuthAuthenticated(
        user: AuthUser(id: 'u1', email: 'x@y.com'),
      );
      const loading = AuthLoading();
      expect(unauth, isA<AuthUnauthenticated>());
      expect(auth, isA<AuthAuthenticated>());
      expect(auth.user.email, 'x@y.com');
      expect(loading, isA<AuthLoading>());
    });
  });

  group('MockAuthRepository', () {
    test('emits auth state changes on sign in/out', () async {
      final repo = MockAuthRepository();
      final events = <AuthUser?>[];
      final sub = repo.authStateChanges().listen(events.add);

      await repo.signInWithGoogle();
      await repo.signOut();

      expect(repo.currentUser, isNull);
      expect(events.length, 2);
      expect(events.last, isNull);
      await sub.cancel();
      repo.dispose();
    });

    test('verification creates a session', () async {
      final repo = MockAuthRepository();
      final user = await repo.verifyEmailOtp('a@b.com', '123456');
      expect(user.id, 'mock-user');
      expect(repo.currentUser?.email, 'a@b.com');
      repo.dispose();
    });

    test('surfaces failures without emitting sessions', () async {
      final repo = MockAuthRepository()..failSignIn = true;
      expect(repo.signInWithGoogle(), throwsException);
      expect(repo.currentUser, isNull);
      repo.dispose();
    });
  });
}
