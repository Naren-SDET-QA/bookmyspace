import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../domain/venue_discovery.dart';
import '../domain/venue_enrichment.dart';
import '../domain/venue_enrichment_provider.dart';

/// Google Places API v1 text search enrichment (server-side / scripts only).
///
/// Uses official Places API — never scrapes Google Maps HTML.
class GooglePlacesEnrichmentProvider implements VenueEnrichmentProvider {
  GooglePlacesEnrichmentProvider({
    required String apiKey,
    Dio? dio,
    this.searchUrl = 'https://places.googleapis.com/v1/places:searchText',
    this.matchRadiusMeters = 500,
    this.minNameScore = 0.45,
  })  : _apiKey = apiKey.trim(),
        _dio = dio ?? Dio();

  final String _apiKey;
  final Dio _dio;
  final String searchUrl;
  final double matchRadiusMeters;
  final double minNameScore;

  @override
  String get sourceCode => VenueDiscoverySources.googlePlaces;

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  static final _fieldMask = [
    'places.id',
    'places.displayName',
    'places.formattedAddress',
    'places.location',
    'places.nationalPhoneNumber',
    'places.websiteUri',
    'places.rating',
    'places.userRatingCount',
    'places.regularOpeningHours',
    'places.photos',
  ].join(',');

  @override
  Future<VenueEnrichmentPatch?> enrich(VenueEnrichmentRequest request) async {
    if (!isConfigured || !request.needsEnrichment) return null;

    final locationHint = [
      request.city,
      request.district,
      request.state,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    final textQuery = locationHint.isEmpty
        ? '${request.name} function hall'
        : '${request.name} function hall $locationHint';

    final response = await _dio.post<Map<String, dynamic>>(
      searchUrl,
      data: {
        'textQuery': textQuery,
        'maxResultCount': 3,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': request.latitude,
              'longitude': request.longitude,
            },
            'radius': matchRadiusMeters,
          },
        },
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': _fieldMask,
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final places = (response.data?['places'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (places.isEmpty) return null;

    final best = _pickBestMatch(request, places);
    if (best == null) return null;

    return _mapPlace(best, request);
  }

  Map<String, dynamic>? _pickBestMatch(
    VenueEnrichmentRequest request,
    List<Map<String, dynamic>> places,
  ) {
    Map<String, dynamic>? best;
    var bestScore = 0.0;

    for (final place in places) {
      final score = _matchScore(request, place);
      if (score > bestScore) {
        bestScore = score;
        best = place;
      }
    }

    if (best == null || bestScore < minNameScore) return null;
    return best;
  }

  double _matchScore(VenueEnrichmentRequest request, Map<String, dynamic> place) {
    final placeName =
        ((place['displayName'] as Map?)?['text'] as String? ?? '').toLowerCase();
    final target = request.name.toLowerCase().trim();
    if (placeName.isEmpty || target.isEmpty) return 0;

    final nameScore = _tokenOverlap(target, placeName);
    final loc = place['location'] as Map<String, dynamic>?;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return nameScore * 0.5;

    final dist = _haversineMeters(
      request.latitude,
      request.longitude,
      lat,
      lng,
    );
    if (dist > matchRadiusMeters) return 0;

    final distScore = 1 - (dist / matchRadiusMeters);
    return (nameScore * 0.7) + (distScore * 0.3);
  }

  double _tokenOverlap(String a, String b) {
    final ta = a.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
    final tb = b.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
    if (ta.isEmpty || tb.isEmpty) return a.contains(b) || b.contains(a) ? 0.6 : 0;
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    return inter / union;
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return r * c;
  }

  double _rad(double deg) => deg * math.pi / 180.0;

  VenueEnrichmentPatch _mapPlace(
    Map<String, dynamic> place,
    VenueEnrichmentRequest request,
  ) {
    final placeId = '${place['id'] ?? ''}'.trim();
    final displayName =
        (place['displayName'] as Map?)?['text'] as String? ?? request.name;
    final fetchedAt = DateTime.now().toUtc().toIso8601String();
    final fields = <String>[];

    String phone = '';
    if (request.existingPhone.isEmpty) {
      phone = '${place['nationalPhoneNumber'] ?? ''}'.trim();
      if (phone.isNotEmpty) fields.add(VenueEnrichmentFields.phone);
    }

    String website = '';
    if (request.existingWebsite.isEmpty) {
      website = '${place['websiteUri'] ?? ''}'.trim();
      if (website.isNotEmpty) fields.add(VenueEnrichmentFields.website);
    }

    final imageRefs = <Map<String, dynamic>>[];
    if (request.existingImageCount == 0) {
      final photos = (place['photos'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .take(3);
      for (final photo in photos) {
        final name = '${photo['name'] ?? ''}';
        if (name.isEmpty) continue;
        imageRefs.add({
          'url':
              'https://places.googleapis.com/v1/$name/media?maxHeightPx=800&key=$_apiKey',
          'alt': displayName,
          'source': VenueDiscoverySources.googlePlaces,
        });
      }
      if (imageRefs.isNotEmpty) fields.add(VenueEnrichmentFields.imageRefs);
    }

    final operatingHours = <Map<String, dynamic>>[];
    if (request.existingHoursEmpty) {
      final hours = place['regularOpeningHours'] as Map<String, dynamic>?;
      final weekdays = hours?['weekdayDescriptions'] as List<dynamic>?;
      if (weekdays != null && weekdays.isNotEmpty) {
        operatingHours.add({
          'source': VenueDiscoverySources.googlePlaces,
          'weekday_descriptions': weekdays,
        });
        fields.add(VenueEnrichmentFields.operatingHours);
      }
    }

    final ratings = <String, dynamic>{};
    if (request.existingRatingsEmpty) {
      final avg = place['rating'];
      final count = place['userRatingCount'];
      if (avg != null) {
        ratings['avg'] = avg;
        ratings['count'] = count ?? 0;
        ratings['source'] = VenueDiscoverySources.googlePlaces;
        fields.add(VenueEnrichmentFields.ratings);
      }
    }

    if (placeId.isNotEmpty) fields.add(VenueEnrichmentFields.googlePlaceId);

    return VenueEnrichmentPatch(
      googlePlaceId: placeId,
      phone: phone,
      website: website,
      imageRefs: imageRefs,
      operatingHours: operatingHours,
      ratings: ratings,
      fieldsEnriched: fields,
      provenance: {
        VenueDiscoverySources.googlePlaces: {
          'place_id': placeId,
          'fetched_at': fetchedAt,
          'fields': fields,
          'match': 'text_search+location_bias',
        },
      },
    );
  }
}
