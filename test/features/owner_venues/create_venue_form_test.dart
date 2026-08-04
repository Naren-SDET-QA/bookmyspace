import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/location/device_location_service.dart';
import 'package:bookmyspace/core/location/location_providers.dart';
import 'package:bookmyspace/core/maps/domain/geo_point.dart';
import 'package:bookmyspace/core/maps/domain/map_providers.dart';
import 'package:bookmyspace/core/maps/maps_providers.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/owner_venues/presentation/screens/create_venue_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_owner_venue_repository.dart';

class _NoopGeocoder implements GeocodingProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<GeocodedPlace?> reverseGeocode(GeoPoint point) async => null;

  @override
  Future<List<GeocodedPlace>> searchAddress(
    String query, {
    int limit = 5,
  }) async =>
      const [];
}

class _NoopLocation implements DeviceLocationService {
  @override
  Future<DeviceLocationResult> currentPosition() async =>
      const DeviceLocationUnavailable('test');
}

List<Override> _overrides(MockOwnerVenueRepository ownerRepo) => [
      ownerVenueRepositoryProvider.overrideWithValue(ownerRepo),
      venueCategoriesProvider.overrideWith(
        (ref) => Future.value(const [
          VenueCategory(id: 'cat-1', slug: 'function_hall', name: 'Hall'),
        ]),
      ),
      geocodingProvider.overrideWithValue(_NoopGeocoder()),
      deviceLocationServiceProvider.overrideWithValue(_NoopLocation()),
    ];

Widget _app(MockOwnerVenueRepository ownerRepo) {
  return ProviderScope(
    overrides: _overrides(ownerRepo),
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CreateVenueScreen(),
    ),
  );
}

void main() {
  testWidgets('create venue blocks empty and invalid fields', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ownerRepo = MockOwnerVenueRepository();
    await tester.pumpWidget(_app(ownerRepo));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Hall'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);
    expect(ownerRepo.lastCreate, isNull);
  });

  testWidgets('create venue rejects negative capacity and price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ownerRepo = MockOwnerVenueRepository();
    await tester.pumpWidget(_app(ownerRepo));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Venue Name'),
      'Test Hall',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'A valid description for the test hall.',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'City');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'State'),
      'State',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacity'),
      '0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Base Price (₹)'),
      '-5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Hall'));
    await tester.pump();

    expect(find.textContaining('valid capacity'), findsOneWidget);
    expect(find.textContaining('valid Price'), findsOneWidget);
    expect(ownerRepo.lastCreate, isNull);
  });
}
