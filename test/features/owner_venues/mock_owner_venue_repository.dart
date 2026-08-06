import 'package:bookmyspace/features/owner_venues/domain/owner_venue_repository.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

class MockOwnerVenueRepository implements OwnerVenueRepository {
  MockOwnerVenueRepository({List<Venue>? venues}) : _venues = venues ?? _default;

  static final _default = [
    MockVenueRepositoryVenue.sample(),
  ];

  final List<Venue> _venues;
  ({String name, int capacity, double price})? lastCreate;

  @override
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? phone,
    String? website,
    List<String>? amenities,
    List<String>? imageUrls,
  }) async {
    lastCreate = (
      name: name,
      capacity: capacity,
      price: pricingBaseAmount,
    );
    return _venues.first;
  }

  @override
  Future<void> deleteVenue(String venueId) async {}

  @override
  Future<List<Venue>> myVenues() async => _venues;

  @override
  Future<OwnerVenueDetail> venueDetail(String venueId) async =>
      OwnerVenueDetail(venue: _venues.first);

  @override
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? phone,
    String? website,
    List<String>? amenities,
    List<String>? imageUrls,
  }) async =>
      _venues.first;
}

/// Minimal venue sample for owner venue tests.
class MockVenueRepositoryVenue {
  static Venue sample() => const Venue(
    id: 'v-owner-1',
    name: 'Owner Hall',
    description: 'Test hall',
    city: 'Hyderabad',
    state: 'Telangana',
    latitude: 17.38,
    longitude: 78.48,
    capacity: 100,
    pricingBaseAmount: 10000,
    category: VenueCategory(id: 'cat-1', slug: 'function_hall', name: 'Hall'),
  );
}
