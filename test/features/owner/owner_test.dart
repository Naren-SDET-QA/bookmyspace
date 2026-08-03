import 'package:test/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../owner_providers.dart';
import 'mock_owner_repository.dart';

class MockOwnerRepository {
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    if (email == 'owner@demo.com' && password == 'password') {
      return Owner(
        id: '1',
        userId: '00000000-0000-0000-0000-000000000002',
        email: 'owner@demo.com',
        name: 'Demo Owner',
      );
    }
    throw Exception('Invalid credentials');
  }

  Future<void> signOut() async {}
}

void main() {
  test('owner sign in works', () {
    final repo = MockOwnerRepository();
    expect(repo.signInWithEmailPassword('owner@demo.com', 'password').then((value) => value.email), equals('owner@demo.com'));
  });
}
