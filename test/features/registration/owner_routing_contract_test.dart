import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'venue_owner role is routed to owner registration, not module registration',
    () {
      final screen = File(
        'lib/features/registration/presentation/unified_registration_screen.dart',
      ).readAsStringSync();

      // The dedicated OTP owner registration route must be used for the
      // venue_owner role entry via an explicit branch.
      expect(
        screen,
        contains("if (module.key == 'venue_owner')"),
        reason: 'venue_owner must be branched to owner registration',
      );
      expect(
        screen,
        contains('context.push(AppRoutes.ownerRegistration)'),
      );
    },
  );

  test('owner registration and module registration routes are distinct', () {
    final router = File(
      'lib/core/router/app_router.dart',
    ).readAsStringSync();

    expect(router, contains("ownerRegistration = '/owner/register'"));
    expect(router, contains("moduleRegistration = '/register/:module'"));
    // Owner registration must be wired to OwnerRegistrationScreen, not the
    // generic ModuleRegistrationScreen.
    expect(
      router,
      contains('OwnerRegistrationScreen()'),
      reason: 'ownerRegistration route must build OwnerRegistrationScreen',
    );
    expect(
      router,
      contains('ModuleRegistrationScreen('),
      reason: 'moduleRegistration route must build ModuleRegistrationScreen',
    );
  });

  test('direct venue_owner module links redirect to the OTP owner flow', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();

    expect(router, contains("state.pathParameters['module'] == 'venue_owner'"));
    expect(router, contains('AppRoutes.ownerRegistration'));
  });

  test('venue_owner stays listed as a registration entry', () {
    final screen = File(
      'lib/features/registration/presentation/unified_registration_screen.dart',
    ).readAsStringSync();

    expect(
      screen,
      contains("key: 'venue_owner'"),
      reason: 'The Venue & space owner entry must still be offered',
    );
  });
}
