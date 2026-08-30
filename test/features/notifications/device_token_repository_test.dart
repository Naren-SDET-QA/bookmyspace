import 'package:flutter_test/flutter_test.dart';

import 'mock_device_token_repository.dart';

void main() {
  group('MockDeviceTokenRepository', () {
    test('registerToken records the token against its platform', () async {
      final repo = MockDeviceTokenRepository();
      await repo.registerToken(token: 'tok-1', platform: 'android');
      expect(repo.registered, {'tok-1': 'android'});
      expect(repo.deregistered, isEmpty);
    });

    test('re-registering the same token refreshes it rather than duplicating it', () async {
      final repo = MockDeviceTokenRepository();
      await repo.registerToken(token: 'tok-1', platform: 'android');
      await repo.registerToken(token: 'tok-1', platform: 'android');
      expect(repo.registered.length, 1);
    });

    test('deregisterToken removes it from the registered set and records it', () async {
      final repo = MockDeviceTokenRepository();
      await repo.registerToken(token: 'tok-1', platform: 'ios');
      await repo.deregisterToken('tok-1');
      expect(repo.registered, isEmpty);
      expect(repo.deregistered, ['tok-1']);
    });

    test('deregistering an unknown token is a safe no-op on the registered set', () async {
      final repo = MockDeviceTokenRepository();
      await repo.deregisterToken('never-registered');
      expect(repo.registered, isEmpty);
      expect(repo.deregistered, ['never-registered']);
    });
  });
}
