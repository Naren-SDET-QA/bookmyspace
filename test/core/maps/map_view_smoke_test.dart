import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/maps/domain/geo_point.dart';
import 'package:bookmyspace/core/maps/domain/map_providers.dart';
import 'package:bookmyspace/core/maps/maps_providers.dart';
import 'package:bookmyspace/core/maps/presentation/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGeocoder implements GeocodingProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<GeocodedPlace?> reverseGeocode(GeoPoint point) async => null;

  @override
  Future<List<GeocodedPlace>> searchAddress(
    String query, {
    int limit = 5,
  }) async =>
      [
        GeocodedPlace(
          displayName: 'Fake Ongole',
          point: const GeoPoint(15.5057, 80.0495),
        ),
      ];
}

class _FakeTiles implements MapTileProvider {
  @override
  String get attribution => 'test';

  @override
  String get urlTemplate =>
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String get userAgentPackageName => 'com.bookmyspace.app';
}

void main() {
  testWidgets('MapView smoke renders marker and search field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapTileProvider.overrideWithValue(_FakeTiles()),
          geocodingProvider.overrideWithValue(_FakeGeocoder()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MapView(
              initialCenter: GeoPoint(15.5057, 80.0495),
              height: 180,
              showAddressSearch: true,
              markers: [
                MapMarkerData(
                  point: GeoPoint(15.5057, 80.0495),
                  label: 'Hall',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MapView), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
