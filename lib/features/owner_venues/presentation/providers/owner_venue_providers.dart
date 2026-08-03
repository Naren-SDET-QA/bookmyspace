import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../domain/owner_venue_repository.dart';
import '../../infrastructure/supabase_owner_venue_repository.dart';

/// Owner venue repository instance.
final ownerVenueRepositoryProvider = Provider<OwnerVenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseOwnerVenueRepository(client);
});

/// List of venues owned by the current owner.
final myVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(ownerVenueRepositoryProvider).myVenues();
});

/// Create a venue and invalidate the list.
final createVenueProvider = FutureProvider.autoDispose
    .family<Venue, ({
      String name,
      String categoryId,
      String description,
      String city,
      String state,
      double latitude,
      double longitude,
      int capacity,
      double pricingBaseAmount,
    })>((ref, params) async {
  final repo = ref.watch(ownerVenueRepositoryProvider);
  final venue = await repo.createVenue(
    name: params.name,
    categoryId: params.categoryId,
    description: params.description,
    city: params.city,
    state: params.state,
    latitude: params.latitude,
    longitude: params.longitude,
    capacity: params.capacity,
    pricingBaseAmount: params.pricingBaseAmount,
  );
  ref.invalidate(myVenuesProvider);
  return venue;
});
