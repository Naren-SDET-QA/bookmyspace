/// Domain models for the configurable venue import engine.
library;

class VenueImportCategoryMapping {
  const VenueImportCategoryMapping({
    required this.id,
    required this.categorySlug,
    required this.displayName,
    this.osmTags = const [],
    this.googlePlaceType = '',
    this.isActive = true,
  });

  final String id;
  final String categorySlug;
  final String displayName;
  final List<String> osmTags;
  final String googlePlaceType;
  final bool isActive;

  factory VenueImportCategoryMapping.fromJson(Map<String, dynamic> json) =>
      VenueImportCategoryMapping(
        id: json['id'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        osmTags: (json['osm_tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        googlePlaceType: json['google_place_type'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

enum VenueImportJobStatus {
  pending,
  fetching,
  review,
  completed,
  failed;

  static VenueImportJobStatus fromString(String? value) {
    return VenueImportJobStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VenueImportJobStatus.pending,
    );
  }
}

class VenueImportJob {
  const VenueImportJob({
    required this.id,
    required this.country,
    required this.state,
    required this.categorySlug,
    this.district = '',
    this.status = VenueImportJobStatus.pending,
    this.source = 'osm',
    this.venuesFetched = 0,
    this.venuesStaged = 0,
    this.venuesDuplicates = 0,
    this.errorMessage = '',
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String country;
  final String state;
  final String district;
  final String categorySlug;
  final VenueImportJobStatus status;
  final String source;
  final int venuesFetched;
  final int venuesStaged;
  final int venuesDuplicates;
  final String errorMessage;
  final DateTime? createdAt;
  final DateTime? completedAt;

  factory VenueImportJob.fromJson(Map<String, dynamic> json) => VenueImportJob(
    id: json['id'] as String? ?? '',
    country: json['country'] as String? ?? '',
    state: json['state'] as String? ?? '',
    district: json['district'] as String? ?? '',
    categorySlug: json['category_slug'] as String? ?? '',
    status: VenueImportJobStatus.fromString(json['status'] as String?),
    source: json['source'] as String? ?? 'osm',
    venuesFetched: (json['venues_fetched'] as num?)?.toInt() ?? 0,
    venuesStaged: (json['venues_staged'] as num?)?.toInt() ?? 0,
    venuesDuplicates: (json['venues_duplicates'] as num?)?.toInt() ?? 0,
    errorMessage: json['error_message'] as String? ?? '',
    createdAt: _parseDate(json['created_at']),
    completedAt: _parseDate(json['completed_at']),
  );
}

enum VenueImportStagingStatus {
  pendingReview,
  approved,
  rejected,
  published,
  duplicate;

  static VenueImportStagingStatus fromString(String? value) {
    switch (value) {
      case 'pending_review':
        return VenueImportStagingStatus.pendingReview;
      case 'approved':
        return VenueImportStagingStatus.approved;
      case 'rejected':
        return VenueImportStagingStatus.rejected;
      case 'published':
        return VenueImportStagingStatus.published;
      case 'duplicate':
        return VenueImportStagingStatus.duplicate;
      default:
        return VenueImportStagingStatus.pendingReview;
    }
  }

  String get dbValue {
    switch (this) {
      case VenueImportStagingStatus.pendingReview:
        return 'pending_review';
      case VenueImportStagingStatus.approved:
        return 'approved';
      case VenueImportStagingStatus.rejected:
        return 'rejected';
      case VenueImportStagingStatus.published:
        return 'published';
      case VenueImportStagingStatus.duplicate:
        return 'duplicate';
    }
  }
}

class VenueImportStagingRow {
  const VenueImportStagingRow({
    required this.id,
    required this.jobId,
    required this.name,
    required this.categorySlug,
    this.status = VenueImportStagingStatus.pendingReview,
    this.addressLine1 = '',
    this.city = '',
    this.district = '',
    this.state = '',
    this.phone = '',
    this.website = '',
    this.latitude = 0,
    this.longitude = 0,
    this.source = 'osm',
    this.sourcePlaceId = '',
    this.googlePlaceId = '',
    this.enrichmentProvenance = const {},
    this.amenities = const [],
    this.operatingHours = const [],
    this.ratings = const {},
    this.imageRefs = const [],
    this.publishedVenueId = '',
    this.fetchedAt,
  });

  final String id;
  final String jobId;
  final String name;
  final String categorySlug;
  final VenueImportStagingStatus status;
  final String addressLine1;
  final String city;
  final String district;
  final String state;
  final String phone;
  final String website;
  final double latitude;
  final double longitude;
  final String source;
  final String sourcePlaceId;
  final String googlePlaceId;
  final Map<String, dynamic> enrichmentProvenance;
  final List<String> amenities;
  final List<Map<String, dynamic>> operatingHours;
  final Map<String, dynamic> ratings;
  final List<Map<String, dynamic>> imageRefs;
  final String publishedVenueId;
  final DateTime? fetchedAt;

  factory VenueImportStagingRow.fromJson(Map<String, dynamic> json) =>
      VenueImportStagingRow(
        id: json['id'] as String? ?? '',
        jobId: json['job_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
        status: VenueImportStagingStatus.fromString(json['status'] as String?),
        addressLine1: json['address_line1'] as String? ?? '',
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        state: json['state'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        website: json['website'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        source: json['source'] as String? ?? 'osm',
        sourcePlaceId: json['source_place_id'] as String? ?? '',
        googlePlaceId: json['google_place_id'] as String? ?? '',
        enrichmentProvenance: Map<String, dynamic>.from(
          json['enrichment_provenance'] as Map? ?? {},
        ),
        amenities: (json['amenities'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        operatingHours: (json['operating_hours'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        ratings: Map<String, dynamic>.from(json['ratings'] as Map? ?? {}),
        imageRefs: (json['image_refs'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        publishedVenueId: json['published_venue_id'] as String? ?? '',
        fetchedAt: _parseDate(json['fetched_at']),
      );

  VenueImportStagingRow copyWith({
    String? id,
    String? jobId,
    String? name,
    String? categorySlug,
    VenueImportStagingStatus? status,
    String? addressLine1,
    String? city,
    String? district,
    String? state,
    String? phone,
    String? website,
    double? latitude,
    double? longitude,
    String? source,
    String? sourcePlaceId,
    String? googlePlaceId,
    Map<String, dynamic>? enrichmentProvenance,
    List<String>? amenities,
    List<Map<String, dynamic>>? operatingHours,
    Map<String, dynamic>? ratings,
    List<Map<String, dynamic>>? imageRefs,
    String? publishedVenueId,
    DateTime? fetchedAt,
  }) =>
      VenueImportStagingRow(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        name: name ?? this.name,
        categorySlug: categorySlug ?? this.categorySlug,
        status: status ?? this.status,
        addressLine1: addressLine1 ?? this.addressLine1,
        city: city ?? this.city,
        district: district ?? this.district,
        state: state ?? this.state,
        phone: phone ?? this.phone,
        website: website ?? this.website,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        source: source ?? this.source,
        sourcePlaceId: sourcePlaceId ?? this.sourcePlaceId,
        googlePlaceId: googlePlaceId ?? this.googlePlaceId,
        enrichmentProvenance: enrichmentProvenance ?? this.enrichmentProvenance,
        amenities: amenities ?? this.amenities,
        operatingHours: operatingHours ?? this.operatingHours,
        ratings: ratings ?? this.ratings,
        imageRefs: imageRefs ?? this.imageRefs,
        publishedVenueId: publishedVenueId ?? this.publishedVenueId,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}

enum VenueClaimStatus {
  pending,
  approved,
  rejected;

  static VenueClaimStatus fromString(String? value) {
    return VenueClaimStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VenueClaimStatus.pending,
    );
  }
}

class VenueClaim {
  const VenueClaim({
    required this.id,
    required this.venueId,
    required this.claimantUserId,
    this.status = VenueClaimStatus.pending,
    this.evidence = const {},
    this.createdAt,
  });

  final String id;
  final String venueId;
  final String claimantUserId;
  final VenueClaimStatus status;
  final Map<String, dynamic> evidence;
  final DateTime? createdAt;

  factory VenueClaim.fromJson(Map<String, dynamic> json) => VenueClaim(
    id: json['id'] as String? ?? '',
    venueId: json['venue_id'] as String? ?? '',
    claimantUserId: json['claimant_user_id'] as String? ?? '',
    status: VenueClaimStatus.fromString(json['status'] as String?),
    evidence: Map<String, dynamic>.from(json['evidence'] as Map? ?? {}),
    createdAt: _parseDate(json['created_at']),
  );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
