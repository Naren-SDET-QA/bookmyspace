/// Phase 3 venue discovery contracts — no bulk import / no live fetch required.
library;

/// Supported discovery source codes (aligned with `venue_sources.code`).
abstract final class VenueDiscoverySources {
  static const osm = 'osm';
  static const googlePlaces = 'google_places';
  static const manual = 'manual';

  static const all = {osm, googlePlaces, manual};
}

/// Country → State → District → Category discovery request.
class VenueDiscoveryQuery {
  const VenueDiscoveryQuery({
    required this.country,
    required this.state,
    required this.categorySlug,
    this.district = '',
    this.sourceCode = VenueDiscoverySources.osm,
    this.osmTags = const [],
  });

  final String country;
  final String state;
  final String categorySlug;

  /// Optional district; empty / "Entire state" = statewide OSM area.
  final String district;
  final String sourceCode;

  /// When empty, provider resolves tags from category config / DB mapping.
  final List<String> osmTags;

  VenueDiscoveryQuery copyWith({
    String? country,
    String? state,
    String? categorySlug,
    String? district,
    String? sourceCode,
    List<String>? osmTags,
  }) =>
      VenueDiscoveryQuery(
        country: country ?? this.country,
        state: state ?? this.state,
        categorySlug: categorySlug ?? this.categorySlug,
        district: district ?? this.district,
        sourceCode: sourceCode ?? this.sourceCode,
        osmTags: osmTags ?? this.osmTags,
      );
}

/// Validation error for a discovery query or candidate.
class VenueDiscoveryValidationException implements Exception {
  VenueDiscoveryValidationException(this.message, {this.field});

  final String message;
  final String? field;

  @override
  String toString() => field == null ? message : '$field: $message';
}

/// Provenance metadata for a discovered venue candidate.
class VenueDiscoveryProvenance {
  const VenueDiscoveryProvenance({
    required this.sourceCode,
    required this.fetchedAt,
    this.sourcePlaceId = '',
    this.sourceUrl = '',
    this.verifiedAt,
  });

  final String sourceCode;
  final DateTime fetchedAt;
  final String sourcePlaceId;
  final String sourceUrl;
  final DateTime? verifiedAt;

  Map<String, dynamic> toJson() => {
        'source_code': sourceCode,
        'source_place_id': sourcePlaceId,
        'source_url': sourceUrl,
        'fetched_at': fetchedAt.toIso8601String(),
        if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      };
}

/// A single discovered venue candidate (not yet staged/imported).
class VenueDiscoveryCandidate {
  const VenueDiscoveryCandidate({
    required this.name,
    required this.categorySlug,
    required this.latitude,
    required this.longitude,
    required this.provenance,
    this.addressLine1 = '',
    this.city = '',
    this.district = '',
    this.state = '',
    this.country = '',
    this.phone = '',
    this.website = '',
    this.amenities = const [],
    this.imageRefs = const [],
    this.raw = const {},
  });

  final String name;
  final String categorySlug;
  final double latitude;
  final double longitude;
  final VenueDiscoveryProvenance provenance;
  final String addressLine1;
  final String city;
  final String district;
  final String state;
  final String country;
  final String phone;
  final String website;
  final List<String> amenities;
  final List<Map<String, dynamic>> imageRefs;
  final Map<String, dynamic> raw;

  String get sourcePlaceId => provenance.sourcePlaceId;
  String get sourceCode => provenance.sourceCode;

  VenueDiscoveryCandidate copyWith({
    String? name,
    String? categorySlug,
    double? latitude,
    double? longitude,
    VenueDiscoveryProvenance? provenance,
    String? addressLine1,
    String? city,
    String? district,
    String? state,
    String? country,
    String? phone,
    String? website,
    List<String>? amenities,
    List<Map<String, dynamic>>? imageRefs,
    Map<String, dynamic>? raw,
  }) =>
      VenueDiscoveryCandidate(
        name: name ?? this.name,
        categorySlug: categorySlug ?? this.categorySlug,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        provenance: provenance ?? this.provenance,
        addressLine1: addressLine1 ?? this.addressLine1,
        city: city ?? this.city,
        district: district ?? this.district,
        state: state ?? this.state,
        country: country ?? this.country,
        phone: phone ?? this.phone,
        website: website ?? this.website,
        amenities: amenities ?? this.amenities,
        imageRefs: imageRefs ?? this.imageRefs,
        raw: raw ?? this.raw,
      );
}

/// Dry-run discovery result (no staging / no bulk import).
class VenueDiscoveryResult {
  const VenueDiscoveryResult({
    required this.query,
    required this.candidates,
    required this.duplicatesDropped,
    required this.fetchedAt,
    this.sourceCode = VenueDiscoverySources.osm,
  });

  final VenueDiscoveryQuery query;
  final List<VenueDiscoveryCandidate> candidates;
  final int duplicatesDropped;
  final DateTime fetchedAt;
  final String sourceCode;

  int get uniqueCount => candidates.length;
}
