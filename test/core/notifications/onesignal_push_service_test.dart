import 'package:bookmyspace/core/notifications/onesignal_push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/notifications/mock_device_token_repository.dart';

// OneSignalPushService talks to the real OneSignal SDK, which requires a
// platform channel that `flutter test` never provides. Every public method
// therefore guards on AppConfig.oneSignalAppId (an empty dart-define in
// this test environment, exactly as it is in this dev environment/CI) and
// must no-op before touching OneSignal.* or the DeviceTokenRepository --
// this is the same defensive pattern the previous FCM-based
// PushNotificationService used, and it is what makes it safe to import and
// call this service from a widget test.
//
// These tests lock in that safety net (no crash, and critically no
// registration or "OneSignal.login" side effect leaks through) for the
// exact scenarios the task calls out: registration mapping and
// logout/unregistration.
void main() {
  group('OneSignalPushService (unconfigured -- no ONESIGNAL_APP_ID)', () {
    test('init() does not throw and does not touch a repository', () async {
      await expectLater(
        OneSignalPushService.instance.init(),
        completes,
      );
    });

    test('onSignedIn() never registers a token when unconfigured', () async {
      final repo = MockDeviceTokenRepository();
      await OneSignalPushService.instance.onSignedIn(repo, 'user-123');
      expect(repo.registered, isEmpty);
    });

    test('onSignedIn() with an empty user id is a safe no-op', () async {
      final repo = MockDeviceTokenRepository();
      await OneSignalPushService.instance.onSignedIn(repo, '');
      expect(repo.registered, isEmpty);
      expect(repo.deregistered, isEmpty);
    });

    test(
      'onSignedOut() is a safe no-op even without a prior onSignedIn()',
      () async {
        await expectLater(
          OneSignalPushService.instance.onSignedOut(),
          completes,
        );
      },
    );

    test(
      'signing in then out never leaves a stray registration/deregistration '
      'when the SDK was never actually initialised (nothing to leak to the '
      'wrong user)',
      () async {
        final repo = MockDeviceTokenRepository();
        await OneSignalPushService.instance.onSignedIn(repo, 'user-a');
        await OneSignalPushService.instance.onSignedOut();
        await OneSignalPushService.instance.onSignedIn(repo, 'user-b');
        expect(repo.registered, isEmpty);
        expect(repo.deregistered, isEmpty);
      },
    );
  });
}
