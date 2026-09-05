import 'dart:convert';

import '../../features/booking/domain/booking.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/infrastructure/transient_network_error.dart';
import '../errors/app_exceptions.dart';
import 'offline_store.dart';

/// Network failures that should fall back to a previously cached snapshot.
bool isOfflineWorthy(Object error) {
  if (error is NetworkException || error is TimeoutException) return true;
  if (isTransientNetworkError(error)) return true;
  final name = error.runtimeType.toString();
  if (name.contains('SocketException') ||
      name.contains('ClientException') ||
      name.contains('HandshakeException') ||
      name.contains('AuthRetryableFetchException')) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('failed host lookup') ||
      text.contains('failed to fetch') ||
      text.contains('xmlhttprequest') ||
      text.contains('network is unreachable');
}

/// JSON disk/memory cache for browse, search and booking lists.
///
/// Online path is unchanged: the live fetch always runs first. A snapshot is
/// written only after a successful response. Cached data is returned only when
/// the live call fails for a connectivity reason.
class OfflineCache {
  OfflineCache(this._store, {this.onServe});

  final OfflineStore _store;

  /// Invoked after each read-through with `true` when the snapshot came
  /// from cache because the live fetch failed.
  final void Function(bool fromCache)? onServe;

  bool servedFromCache = false;

  void _remember(bool fromCache) {
    servedFromCache = fromCache;
    onServe?.call(fromCache);
  }

  static String searchKey(VenueSearchQuery query) =>
      'search:${query.query}|${query.sectionId}|${query.categorySlug}|'
      '${query.city}|${query.latitude}|${query.longitude}|${query.sortBy.name}';

  static const popularKey = 'venues.popular';
  static const nearbyKey = 'venues.nearby';
  static const bookingsKey = 'bookings.mine';

  static String venueKey(String id) => 'venue.$id';
  static String moduleKey(String moduleId) => 'venues.module.$moduleId';

  Future<void> saveVenues(String key, List<Venue> venues) async {
    await _store.write(
      key,
      jsonEncode(venues.map(venueToCache).toList(growable: false)),
    );
  }

  Future<List<Venue>?> loadVenues(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final row in decoded)
          if (row is Map<String, dynamic>)
            Venue.fromJson(row)
          else if (row is Map<dynamic, dynamic>)
            Venue.fromJson(Map<String, dynamic>.from(row)),
      ];
    } on FormatException {
      await _store.delete(key);
      return null;
    } on TypeError {
      await _store.delete(key);
      return null;
    }
  }

  Future<void> saveBookings(String key, List<Booking> bookings) async {
    await _store.write(
      key,
      jsonEncode(bookings.map(bookingToCache).toList(growable: false)),
    );
  }

  Future<List<Booking>?> loadBookings(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final row in decoded)
          if (row is Map<String, dynamic>)
            Booking.fromJson(row)
          else if (row is Map<dynamic, dynamic>)
            Booking.fromJson(Map<String, dynamic>.from(row)),
      ];
    } on FormatException {
      await _store.delete(key);
      return null;
    } on TypeError {
      await _store.delete(key);
      return null;
    }
  }

  Future<List<Venue>> readThroughVenues(
    String key,
    Future<List<Venue>> Function() fetch,
  ) async {
    try {
      final live = await fetch();
      await saveVenues(key, live);
      _remember(false);
      return live;
    } catch (error) {
      if (!isOfflineWorthy(error)) rethrow;
      final cached = await loadVenues(key);
      if (cached == null) rethrow;
      _remember(true);
      return cached;
    }
  }

  Future<Venue> readThroughVenue(
    String id,
    Future<Venue> Function() fetch,
  ) async {
    try {
      final live = await fetch();
      await saveVenues(venueKey(id), [live]);
      _remember(false);
      return live;
    } catch (error) {
      if (!isOfflineWorthy(error)) rethrow;
      final cached = await loadVenues(venueKey(id));
      if (cached == null || cached.isEmpty) rethrow;
      _remember(true);
      return cached.first;
    }
  }

  Future<List<Booking>> readThroughBookings(
    String key,
    Future<List<Booking>> Function() fetch,
  ) async {
    try {
      final live = await fetch();
      await saveBookings(key, live);
      _remember(false);
      return live;
    } catch (error) {
      if (!isOfflineWorthy(error)) rethrow;
      final cached = await loadBookings(key);
      if (cached == null) rethrow;
      _remember(true);
      return cached;
    }
  }
}

Map<String, dynamic> venueToCache(Venue venue) => {
  'id': venue.id,
  'name': venue.name,
  'slug': venue.slug,
  'description': venue.description,
  'address_line1': venue.addressLine1,
  'address_line2': venue.addressLine2,
  'city': venue.city,
  'state': venue.state,
  'postal_code': venue.postalCode,
  'country': venue.country,
  'location_node_id': venue.locationNodeId,
  'latitude': venue.latitude,
  'longitude': venue.longitude,
  'capacity': venue.capacity,
  'pricing_base_amount': venue.pricingBaseAmount,
  'pricing_currency': venue.pricingCurrency,
  'tax_rate': venue.taxRate,
  'avg_rating': venue.avgRating,
  'rating_count': venue.ratingCount,
  'is_verified': venue.isVerified,
  'is_active': venue.isActive,
  'distance_km': venue.distanceKm,
  'contact_whatsapp': venue.contactWhatsapp,
  'listing_status': venue.listingStatus,
  'venue_categories': venue.category == null
      ? null
      : {
          'id': venue.category!.id,
          'slug': venue.category!.slug,
          'name': venue.category!.name,
          'icon': venue.category!.icon,
        },
  'venue_images': [
    for (final image in venue.images)
      {
        'id': image.id,
        'url': image.url,
        'thumbnail_url': image.thumbnailUrl,
        'is_cover': image.isCover,
        'media_kind': image.mediaKind,
      },
  ],
};

Map<String, dynamic> bookingToCache(Booking booking) => {
  'id': booking.id,
  'booking_ref': booking.bookingRef,
  'venue_id': booking.venueId,
  'slot_id': booking.slotId,
  'book_date': booking.bookDate.toIso8601String(),
  'start_time': booking.startTime,
  'end_time': booking.endTime,
  'status': booking.status.dbValue,
  'amount': booking.amount,
  'tax_amount': booking.taxAmount,
  'total_amount': booking.totalAmount,
  'discount_amount': booking.discountAmount,
  'created_at': booking.createdAt?.toIso8601String(),
  'venues': {'name': booking.venueName, 'city': booking.venueCity},
  'time_slots': {'label': booking.slotLabel},
  'metadata': {
    ...booking.metadata,
    'customer_name': booking.customerName,
    'customer_phone': booking.customerPhone,
    if (booking.isOffline) 'offline_booking': true,
    if (booking.holdExpiresAt != null)
      'hold_expires_at': booking.holdExpiresAt!.toUtc().toIso8601String(),
  },
};
