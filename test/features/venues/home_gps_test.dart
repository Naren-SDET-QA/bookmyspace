import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/location/device_location_service.dart';
import 'package:bookmyspace/core/location/location_providers.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import 'mock_venue_repository.dart';

class _FakeLocationService implements DeviceLocationService {
  _FakeLocationService(this.result);

  final DeviceLocationResult result;
  var callCount = 0;

  @override
  Future<DeviceLocationResult> currentPosition() async {
    callCount++;
    return result;
  }
}

Widget _app(
  MockVenueRepository venueRepo, {
  DeviceLocationService? locationService,
}) {
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(venueRepo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      if (locationService != null)
        deviceLocationServiceProvider.overrideWithValue(locationService),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: AppRoutes.home,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
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
}

void main() {
  testWidgets('GPS location updates search area on success', (tester) async {
    final repo = MockVenueRepository();
    final location = _FakeLocationService(
      const DeviceLocationSuccess(
        latitude: 16.3067,
        longitude: 80.4365,
        accuracyMeters: 12,
      ),
    );

    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(repo, locationService: location));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ongole, Andhra Pradesh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(location.callCount, 1);
    expect(find.text('Current location'), findsNWidgets(2));
    expect(repo.lastNearbyLatitude, closeTo(16.3067, 0.0001));
    expect(repo.lastNearbyLongitude, closeTo(80.4365, 0.0001));
  });

  testWidgets('GPS permission denied shows resilient snackbar', (tester) async {
    final repo = MockVenueRepository();
    final location = _FakeLocationService(
      const DeviceLocationPermissionDenied(),
    );

    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(repo, locationService: location));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ongole, Andhra Pradesh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Ongole, Andhra Pradesh'), findsOneWidget);
  });
}
