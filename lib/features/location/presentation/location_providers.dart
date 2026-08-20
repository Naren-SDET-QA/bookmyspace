import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_area.dart';
import '../domain/location_node.dart';
import '../infrastructure/geocoding_service.dart';
import '../infrastructure/supabase_location_repository.dart';
import '../../auth/presentation/auth_providers.dart';

/// Geocoding / device-location service instance.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

final locationRepositoryProvider = Provider<SupabaseLocationRepository>((ref) {
  return SupabaseLocationRepository(ref.watch(supabaseProvider));
});

final locationChildrenProvider = FutureProvider.autoDispose
    .family<List<LocationNode>, ({String? parentId, LocationNodeLevel level})>(
      (ref, request) => ref
          .watch(locationRepositoryProvider)
          .children(parentId: request.parentId, level: request.level),
    );

final locationSearchProvider = FutureProvider.autoDispose
    .family<List<LocationNode>, String>((ref, query) {
      if (query.trim().isEmpty) return const [];
      return ref.watch(locationRepositoryProvider).search(query.trim());
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
final geocodePlaceProvider = FutureProvider.autoDispose
    .family<SearchArea?, String>((ref, query) {
      return ref.watch(geocodingServiceProvider).geocode(query);
    });

/// Reverse geocoding of map coordinates to a readable label.
final reverseGeocodeProvider = FutureProvider.autoDispose
    .family<String, (double, double)>((ref, point) {
      return ref.watch(geocodingServiceProvider).reverse(point.$1, point.$2);
    });
