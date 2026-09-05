import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/auth/mock_auth_repository.dart';
import '../test/features/booking/mock_booking_repository.dart';
import '../test/features/courses/mock_course_repository.dart';
import '../test/features/events/mock_event_repository.dart';
import '../test/features/notifications/mock_notification_repository.dart';
import '../test/features/venues/mock_venue_repository.dart';

Widget testApp(String route) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      MockAuthRepository(
        initialUser: const AuthUser(id: 'e2e-user', email: 'e2e@test.local'),
      ),
    ),
    authConfigurationProvider.overrideWith(
      (_) async => const AuthConfiguration(
        authenticationEnabled: true,
        emailLoginEnabled: true,
        emailOtpEnabled: true,
        phoneLoginEnabled: true,
        phoneOtpEnabled: true,
      ),
    ),
    venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
    bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    notificationRepositoryProvider.overrideWithValue(
      MockNotificationRepository(),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: createAppRouter(
      initialLocation: route,
      currentUser: const AuthUser(id: 'e2e-user', email: 'e2e@test.local'),
    ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and home is reachable', (tester) async {
    await tester.pumpWidget(testApp(AppRoutes.home));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stay'), findsWidgets);
  });

  testWidgets('venue navigation reaches booking step without payment', (
    tester,
  ) async {
    await tester.pumpWidget(testApp('/venues/v1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Book Now'), findsOneWidget);
    await tester.tap(find.textContaining('Book Now'));
    await tester.pumpAndSettle();
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Continue'), findsWidgets);
  });
}
