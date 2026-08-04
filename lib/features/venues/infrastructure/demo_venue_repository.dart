import '../domain/venue.dart';
import '../domain/venue_repository.dart';

/// Offline / Demo implementation of [VenueRepository] matching the BookMySpace design prototype.
class DemoVenueRepository implements VenueRepository {
  DemoVenueRepository();

  final List<String> _favoriteIds = ['v1', 'v3'];

  static const List<VenueCategory> _categories = [
    VenueCategory(id: 'c1', slug: 'venues', name: 'Venues', icon: 'festival'),
    VenueCategory(id: 'c2', slug: 'sports', name: 'Sports', icon: 'sports_soccer'),
    VenueCategory(id: 'c3', slug: 'work', name: 'Work', icon: 'work'),
    VenueCategory(id: 'c4', slug: 'classes', name: 'Classes', icon: 'menu_book'),
    VenueCategory(id: 'c5', slug: 'parties', name: 'Parties', icon: 'celebration'),
    VenueCategory(id: 'c6', slug: 'events', name: 'Events', icon: 'event'),
    VenueCategory(id: 'c7', slug: 'studios', name: 'Studios', icon: 'mic'),
    VenueCategory(id: 'c8', slug: 'stays', name: 'Stays', icon: 'bed'),
  ];

  static final List<Venue> _sampleVenues = [
    const Venue(
      id: 'v1',
      name: 'Skyline Rooftop Lounge',
      latitude: 12.9716,
      longitude: 77.5946,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 150,
      pricingBaseAmount: 85,
      avgRating: 4.9,
      ratingCount: 128,
      isVerified: true,
      distanceKm: 1.2,
      category: VenueCategory(id: 'c1', slug: 'venues', name: 'Venue', icon: 'festival'),
      images: [
        VenueImage(
          id: 'img1',
          url: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'Panoramic View'),
        VenueFacility(facility: 'DJ Booth & Sound System'),
        VenueFacility(facility: 'Full Bar & Catering'),
        VenueFacility(facility: 'High-Speed WiFi'),
        VenueFacility(facility: 'Valet Parking'),
      ],
    ),
    const Venue(
      id: 'v2',
      name: 'Pro Turf Arena - Indiranagar',
      latitude: 12.9784,
      longitude: 77.6408,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 50,
      pricingBaseAmount: 40,
      avgRating: 4.8,
      ratingCount: 94,
      isVerified: true,
      distanceKm: 2.1,
      category: VenueCategory(id: 'c2', slug: 'sports', name: 'Sports', icon: 'sports_soccer'),
      images: [
        VenueImage(
          id: 'img2',
          url: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'FIFA Approved Turf'),
        VenueFacility(facility: 'Floodlights'),
        VenueFacility(facility: 'Changing Rooms'),
      ],
    ),
    const Venue(
      id: 'v3',
      name: 'Creative Podcast & Photo Studio',
      latitude: 12.9698,
      longitude: 77.7500,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 20,
      pricingBaseAmount: 60,
      avgRating: 4.95,
      ratingCount: 56,
      isVerified: true,
      distanceKm: 0.8,
      category: VenueCategory(id: 'c7', slug: 'studios', name: 'Studio', icon: 'mic'),
      images: [
        VenueImage(
          id: 'img3',
          url: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'Acoustic Soundproofing'),
        VenueFacility(facility: '4K Microphones'),
        VenueFacility(facility: 'Softbox Lighting'),
      ],
    ),
    const Venue(
      id: 'v4',
      name: 'Grand Banquet Hall',
      latitude: 12.9352,
      longitude: 77.6245,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 300,
      pricingBaseAmount: 120,
      avgRating: 4.7,
      ratingCount: 82,
      isVerified: true,
      distanceKm: 3.5,
      category: VenueCategory(id: 'c1', slug: 'venues', name: 'Venue', icon: 'celebration'),
      images: [
        VenueImage(
          id: 'img4',
          url: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'Air Conditioning'),
        VenueFacility(facility: 'Stage & Lighting'),
        VenueFacility(facility: 'In-house Catering'),
      ],
    ),
    const Venue(
      id: 'v5',
      name: 'Sunset Terrace Garden',
      latitude: 12.9250,
      longitude: 77.5898,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 80,
      pricingBaseAmount: 70,
      avgRating: 4.85,
      ratingCount: 64,
      isVerified: true,
      distanceKm: 2.1,
      category: VenueCategory(id: 'c1', slug: 'venues', name: 'Venue', icon: 'deck'),
      images: [
        VenueImage(
          id: 'img5',
          url: 'https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'Fire Pits'),
        VenueFacility(facility: 'Garden Seating'),
      ],
    ),
    const Venue(
      id: 'v6',
      name: 'Penthouse Co-working Space',
      latitude: 12.9716,
      longitude: 77.5946,
      city: 'Bengaluru',
      state: 'KA',
      capacity: 40,
      pricingBaseAmount: 35,
      avgRating: 4.6,
      ratingCount: 45,
      isVerified: true,
      distanceKm: 0.8,
      category: VenueCategory(id: 'c3', slug: 'work', name: 'Work', icon: 'work'),
      images: [
        VenueImage(
          id: 'img6',
          url: 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80',
          isCover: true,
        ),
      ],
      facilities: [
        VenueFacility(facility: 'High-Speed WiFi'),
        VenueFacility(facility: 'Free Coffee'),
        VenueFacility(facility: 'Meeting Pods'),
      ],
    ),
  ];

  @override
  Future<List<VenueCategory>> categories() async => _categories;

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async =>
      _sampleVenues.take(limit).toList();

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async => _sampleVenues.take(limit).toList();

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    return _sampleVenues.where((v) {
      if (query.query.trim().isNotEmpty &&
          !v.name.toLowerCase().contains(query.query.toLowerCase()) &&
          !v.city.toLowerCase().contains(query.query.toLowerCase())) {
        return false;
      }
      if (query.maxPrice != null && v.pricingBaseAmount > query.maxPrice!) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Venue> venueById(String id) async {
    return _sampleVenues.firstWhere(
      (v) => v.id == id,
      orElse: () => _sampleVenues.first,
    );
  }

  @override
  Future<List<String>> favoriteIds() async => List.unmodifiable(_favoriteIds);

  @override
  Future<List<Venue>> favorites() async {
    return _sampleVenues.where((v) => _favoriteIds.contains(v.id)).toList();
  }

  @override
  Future<void> addFavorite(String venueId) async {
    if (!_favoriteIds.contains(venueId)) _favoriteIds.add(venueId);
  }

  @override
  Future<void> removeFavorite(String venueId) async {
    _favoriteIds.remove(venueId);
  }
}
