import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_area.dart';
import '../infrastructure/geocoding_service.dart';

/// Geocoding / device-location service instance.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

/// The currently selected search area (label + coordinates + radius).
///
/// Shared by the home screen, search screen, map screen and any future
/// section flow so location stays consistent app-wide.
final searchAreaProvider = StateProvider<SearchArea>((ref) {
  return SearchArea.defaultArea;
});

/// Result of asking the device for its current position. `null` while
/// unknown / denied; the async error carries the reason.
final deviceLocationProvider = FutureProvider.autoDispose<SearchArea>((ref) {
  return ref.watch(geocodingServiceProvider).deviceLocation();
});

/// Forward geocoding of a free-text place name (Nominatim).
final geocodePlaceProvider =
    FutureProvider.autoDispose.family<SearchArea?, String>((ref, query) {
  return ref.watch(geocodingServiceProvider).geocode(query);
});

/// Reverse geocoding of map coordinates to a readable label.
final reverseGeocodeProvider =
    FutureProvider.autoDispose.family<String, (double, double)>((ref, point) {
  return ref
      .watch(geocodingServiceProvider)
      .reverse(point.$1, point.$2);
});