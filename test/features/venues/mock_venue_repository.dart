import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/domain/venue_repository.dart';

/// In-memory venue repository for tests and widget tests.
class MockVenueRepository implements VenueRepository {
  MockVenueRepository({List<Venue>? venues})
    : _venues = venues ?? defaultVenues;

  final List<Venue> _venues;
  final Set<String> _favorites = {};
  bool failRequests = false;

  /// Tracks the last query passed to [search].
  VenueSearchQuery? lastSearchQuery;

  static const VenueCategory _functionHall = VenueCategory(
    id: 'cat-1',
    slug: 'function_hall',
    name: 'Function Hall',
  );
  static const VenueCategory _meetingRoom = VenueCategory(
    id: 'cat-2',
    slug: 'meeting_room',
    name: 'Meeting Room',
  );

  static const List<Venue> defaultVenues = [
    Venue(
      id: 'v1',
      name: 'Sunrise Function Hall',
      description: 'A spacious hall in the heart of the city.',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.385044,
      longitude: 78.486671,
      capacity: 500,
      pricingBaseAmount: 35000,
      isVerified: true,
      avgRating: 4.8,
      ratingCount: 120,
      category: _functionHall,
      images: [
        VenueImage(
          id: 'i1',
          url: 'https://example.com/sunrise.jpg',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'Air Conditioning'),
        VenueFacility(facility: 'Parking'),
      ],
    ),
    Venue(
      id: 'v2',
      name: 'The Boardroom',
      description: 'Modern meeting rooms for teams of 8-20.',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.4246,
      longitude: 78.4481,
      capacity: 20,
      pricingBaseAmount: 2500,
      avgRating: 4.5,
      ratingCount: 64,
      category: _meetingRoom,
      images: [
        VenueImage(
          id: 'i2',
          url: 'https://example.com/boardroom.jpg',
          isCover: true,
        ),
      ],
    ),
    Venue(
      id: 'v3',
      name: 'The Work Nest',
      description: 'Flexible coworking with high-speed internet.',
      city: 'Bengaluru',
      state: 'Karnataka',
      latitude: 12.9716,
      longitude: 77.5946,
      capacity: 80,
      pricingBaseAmount: 500,
      isVerified: true,
      avgRating: 4.7,
      ratingCount: 214,
      category: VenueCategory(
        id: 'cat-3',
        slug: 'coworking_space',
        name: 'Coworking Space',
      ),
    ),
    Venue(
      id: 'v4',
      name: 'Crown Lodge Rooms',
      description: 'Budget lodge and hotel rooms near the metro.',
      city: 'Hyderabad',
      latitude: 17.44,
      longitude: 78.39,
      capacity: 4,
      pricingBaseAmount: 2800,
      avgRating: 4.4,
      ratingCount: 40,
      category: VenueCategory(id: 'cat-4', slug: 'hotel_stay', name: 'Hotel'),
    ),
    Venue(
      id: 'v5',
      name: 'Starlight Ladies PG',
      description: 'Safe ladies PG hostel with food and wifi.',
      city: 'Hyderabad',
      latitude: 17.45,
      longitude: 78.37,
      capacity: 3,
      pricingBaseAmount: 9000,
      avgRating: 4.9,
      ratingCount: 80,
      category: VenueCategory(id: 'cat-5', slug: 'pg_hostel', name: 'PG'),
    ),
    Venue(
      id: 'v6',
      name: 'Apex Sports Academy',
      description: 'Badminton coaching and sports turf listings.',
      city: 'Hyderabad',
      latitude: 17.42,
      longitude: 78.40,
      capacity: 30,
      pricingBaseAmount: 450,
      avgRating: 4.6,
      ratingCount: 22,
      category: VenueCategory(
        id: 'cat-6',
        slug: 'sports_ground',
        name: 'Sports Ground',
      ),
    ),
  ];

  @override
  Future<List<VenueCategory>> categories() async {
    if (failRequests) throw Exception('network down');
    return [
      _functionHall,
      _meetingRoom,
      const VenueCategory(
        id: 'cat-3',
        slug: 'coworking_space',
        name: 'Coworking Space',
      ),
      const VenueCategory(id: 'cat-hotel', slug: 'hotel_stay', name: 'Hotel / Stay'),
      const VenueCategory(id: 'cat-lodge', slug: 'lodge', name: 'Lodge'),
      const VenueCategory(id: 'cat-pg', slug: 'pg_coliving', name: 'PG / Co-Living'),
      const VenueCategory(id: 'cat-ladies', slug: 'ladies_pg', name: 'Ladies PG'),
      const VenueCategory(id: 'cat-sport', slug: 'sports_ground', name: 'Sports Ground'),
      const VenueCategory(id: 'cat-mh', slug: 'marriage_hall', name: 'Marriage Hall'),
      const VenueCategory(id: 'cat-dance', slug: 'dance_academy', name: 'Dance Academy'),
    ];
  }

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async {
    if (failRequests) throw Exception('network down');
    final sorted = [..._venues]
      ..sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async {
    if (failRequests) throw Exception('network down');
    final withDistance = _venues
        .map((v) => v.copyWith(distanceKm: 1.0))
        .toList();
    return withDistance.take(limit).toList();
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    if (failRequests) throw Exception('network down');
    lastSearchQuery = query;
    final results = _venues.where((v) {
      final matchesQuery =
          query.query.isEmpty ||
          v.name.toLowerCase().contains(query.query.toLowerCase()) ||
          v.city.toLowerCase().contains(query.query.toLowerCase());
      final matchesCategory =
          query.categorySlug == null ||
          query.categorySlug == 'all' ||
          v.category?.slug == query.categorySlug;
      final section = CustomerSection.fromId(query.sectionId);
      final matchesSection =
          section == null ||
          CustomerSectionCatalog.matchesVenue(v, section, query.categorySlug);
      final matchesMin =
          query.minPrice == null || v.pricingBaseAmount >= query.minPrice!;
      final matchesMax =
          query.maxPrice == null || v.pricingBaseAmount <= query.maxPrice!;
      return matchesQuery &&
          matchesCategory &&
          matchesSection &&
          matchesMin &&
          matchesMax;
    }).toList();

    switch (query.sortBy) {
      case VenueSortBy.priceAsc:
        results.sort(
          (a, b) => a.pricingBaseAmount.compareTo(b.pricingBaseAmount),
        );
      case VenueSortBy.priceDesc:
        results.sort(
          (a, b) => b.pricingBaseAmount.compareTo(a.pricingBaseAmount),
        );
      case VenueSortBy.rating:
        results.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      case VenueSortBy.distance:
      case VenueSortBy.relevance:
        results.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    }
    return results;
  }

  @override
  Future<Venue> venueById(String id) async {
    if (failRequests) throw Exception('network down');
    return _venues.firstWhere(
      (v) => v.id == id,
      orElse: () => throw Exception('Venue not found'),
    );
  }

  @override
  Future<List<String>> favoriteIds() async {
    if (failRequests) throw Exception('network down');
    return _favorites.toList();
  }

  @override
  Future<List<Venue>> favorites() async {
    if (failRequests) throw Exception('network down');
    return _venues.where((v) => _favorites.contains(v.id)).toList();
  }

  @override
  Future<void> addFavorite(String venueId) async {
    if (failRequests) throw Exception('network down');
    _favorites.add(venueId);
  }

  @override
  Future<void> removeFavorite(String venueId) async {
    if (failRequests) throw Exception('network down');
    _favorites.remove(venueId);
  }
}
