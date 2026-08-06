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

/// Full venue detail (with gallery + facilities) for the edit screen.
final ownerVenueDetailProvider = FutureProvider.autoDispose
    .family<OwnerVenueDetail, String>((ref, venueId) {
      return ref.watch(ownerVenueRepositoryProvider).venueDetail(venueId);
    });

/// Create a venue and invalidate the list.
final createVenueProvider = FutureProvider.autoDispose
    .family<
      Venue,
      ({
        String name,
        String categoryId,
        String description,
        String city,
        String state,
        double latitude,
        double longitude,
        int capacity,
        double pricingBaseAmount,
        String? addressLine1,
        String? addressLine2,
        String? postalCode,
        String? phone,
        String? website,
        List<String>? amenities,
        List<String>? imageUrls,
      })
    >((ref, params) async {
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
        addressLine1: params.addressLine1,
        addressLine2: params.addressLine2,
        postalCode: params.postalCode,
        phone: params.phone,
        website: params.website,
        amenities: params.amenities,
        imageUrls: params.imageUrls,
      );
      ref.invalidate(myVenuesProvider);
      return venue;
    });

final updateVenueProvider = FutureProvider.autoDispose
    .family<
      Venue,
      ({
        String venueId,
        String name,
        String categoryId,
        String description,
        String city,
        String state,
        double latitude,
        double longitude,
        int capacity,
        double pricingBaseAmount,
        String? addressLine1,
        String? addressLine2,
        String? postalCode,
        String? phone,
        String? website,
        List<String>? amenities,
        List<String>? imageUrls,
      })
    >((ref, p) async {
      final venue = await ref
          .watch(ownerVenueRepositoryProvider)
          .updateVenue(
            venueId: p.venueId,
            name: p.name,
            categoryId: p.categoryId,
            description: p.description,
            city: p.city,
            state: p.state,
            latitude: p.latitude,
            longitude: p.longitude,
            capacity: p.capacity,
            pricingBaseAmount: p.pricingBaseAmount,
            addressLine1: p.addressLine1,
            addressLine2: p.addressLine2,
            postalCode: p.postalCode,
            phone: p.phone,
            website: p.website,
            amenities: p.amenities,
            imageUrls: p.imageUrls,
          );
      ref.invalidate(myVenuesProvider);
      return venue;
    });
