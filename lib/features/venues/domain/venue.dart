/// Venue categories as seeded in `venue_categories`.
///
/// NOTE: Freeze/JsonSerializable codegen is configured but was not run in this
/// environment; the class is hand-written to stay dependency-free.
class VenueCategory {
  const VenueCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.icon = '',
  });

  final String id;
  final String slug;
  final String name;
  final String icon;

  factory VenueCategory.fromJson(Map<String, dynamic> json) => VenueCategory(
    id: json['id'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
  );
}

/// A single venue image row from `venue_images`.
class VenueImage {
  const VenueImage({
    required this.id,
    required this.url,
    this.thumbnailUrl = '',
    this.altText = '',
    this.isCover = false,
    this.sortOrder = 0,
  });

  final String id;
  final String url;
  final String thumbnailUrl;
  final String altText;
  final bool isCover;
  final int sortOrder;

  factory VenueImage.fromJson(Map<String, dynamic> json) => VenueImage(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    altText: json['alt_text'] as String? ?? '',
    isCover: json['is_cover'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
}

/// A facility offered by a venue (`venue_facilities`).
class VenueFacility {
  const VenueFacility({required this.facility, this.isAvailable = true});

  final String facility;
  final bool isAvailable;

  factory VenueFacility.fromJson(Map<String, dynamic> json) => VenueFacility(
    facility: json['facility'] as String? ?? '',
    isAvailable: json['is_available'] as bool? ?? true,
  );
}

/// Operating hours for one day of the week (`venue_operating_hours`).
class VenueOperatingHours {
  const VenueOperatingHours({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
  });

  final int dayOfWeek;
  final String opensAt;
  final String closesAt;
  final bool isClosed;

  factory VenueOperatingHours.fromJson(Map<String, dynamic> json) =>
      VenueOperatingHours(
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        opensAt: json['opens_at'] as String? ?? '09:00:00',
        closesAt: json['closes_at'] as String? ?? '18:00:00',
        isClosed: json['is_closed'] as bool? ?? false,
      );
}

/// A bookable venue.
///
/// Rich object combining `venues` with its category, cover image, facilities
/// and operating hours. List endpoints return a light version; the details
/// endpoint hydrates the collections.
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.slug = '',
    this.description = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = 'IN',
    this.capacity = 0,
    this.pricingBaseAmount = 0,
    this.pricingCurrency = 'INR',
    this.taxRate = 0,
    this.parkingCapacity = 0,
    this.foodOptions = '',
    this.rules = '',
    this.isVerified = false,
    this.isActive = true,
    this.avgRating = 0,
    this.ratingCount = 0,
    this.category,
    this.images = const [],
    this.facilities = const [],
    this.operatingHours = const [],
    this.distanceKm,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double latitude;
  final double longitude;
  final int capacity;
  final double pricingBaseAmount;
  final String pricingCurrency;
  final double taxRate;
  final int parkingCapacity;
  final String foodOptions;
  final String rules;
  final bool isVerified;
  final bool isActive;
  final double avgRating;
  final int ratingCount;
  final VenueCategory? category;

  /// Hydrated collections (empty in list responses).
  final List<VenueImage> images;
  final List<VenueFacility> facilities;
  final List<VenueOperatingHours> operatingHours;

  /// Distance in kilometres from the query point, when computed.
  final double? distanceKm;

  /// Cover image URL (first cover, else first image, else placeholder).
  String get coverImageUrl {
    if (images.isEmpty) return '';
    for (final image in images) {
      if (image.isCover) return image.url;
    }
    return images.first.url;
  }

  /// Address composed from address lines + city + state.
  String get address => [
    addressLine1,
    addressLine2,
    city,
    state,
  ].where((p) => p.trim().isNotEmpty).join(', ');

  /// Base price formatted without currency symbol (used with a currency label).
  double get price => pricingBaseAmount;

  factory Venue.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['venue_categories'] ?? json['category'];
    final imagesRaw = json['venue_images'] ?? const <dynamic>[];
    final facilitiesRaw = json['venue_facilities'] ?? const <dynamic>[];
    final hoursRaw = json['venue_operating_hours'] ?? const <dynamic>[];

    return Venue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      addressLine1: json['address_line1'] as String? ?? '',
      addressLine2: json['address_line2'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: json['country'] as String? ?? 'IN',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      pricingBaseAmount: (json['pricing_base_amount'] as num?)?.toDouble() ?? 0,
      pricingCurrency: json['pricing_currency'] as String? ?? 'INR',
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      parkingCapacity: (json['parking_capacity'] as num?)?.toInt() ?? 0,
      foodOptions: json['food_options'] as String? ?? '',
      rules: json['rules'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      category: categoryRaw is Map<String, dynamic>
          ? VenueCategory.fromJson(categoryRaw)
          : null,
      images: imagesRaw is List
          ? imagesRaw
                .whereType<Map<String, dynamic>>()
                .map(VenueImage.fromJson)
                .toList()
          : const [],
      facilities: facilitiesRaw is List
          ? facilitiesRaw
                .whereType<Map<String, dynamic>>()
                .map(VenueFacility.fromJson)
                .toList()
          : const [],
      operatingHours: hoursRaw is List
          ? hoursRaw
                .whereType<Map<String, dynamic>>()
                .map(VenueOperatingHours.fromJson)
                .toList()
          : const [],
    );
  }

  Venue copyWith({
    List<VenueImage>? images,
    List<VenueFacility>? facilities,
    List<VenueOperatingHours>? operatingHours,
    double? distanceKm,
    double? avgRating,
    int? ratingCount,
  }) {
    return Venue(
      id: id,
      name: name,
      slug: slug,
      description: description,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      pricingBaseAmount: pricingBaseAmount,
      pricingCurrency: pricingCurrency,
      taxRate: taxRate,
      parkingCapacity: parkingCapacity,
      foodOptions: foodOptions,
      rules: rules,
      isVerified: isVerified,
      isActive: isActive,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      category: category,
      images: images ?? this.images,
      facilities: facilities ?? this.facilities,
      operatingHours: operatingHours ?? this.operatingHours,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}

/// A search query describing the filters applied to venue listings.
class VenueSearchQuery {
  const VenueSearchQuery({
    this.query = '',
    this.categorySlug,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.sortBy = VenueSortBy.relevance,
    this.latitude,
    this.longitude,
    this.maxDistanceKm,
  });

  final String query;
  final String? categorySlug;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final VenueSortBy sortBy;
  final double? latitude;
  final double? longitude;
  final double? maxDistanceKm;

  bool get hasFilters =>
      query.isNotEmpty ||
      categorySlug != null ||
      city != null ||
      minPrice != null ||
      maxPrice != null;

  VenueSearchQuery copyWith({
    String? query,
    String? Function()? categorySlug,
    String? Function()? city,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    VenueSortBy? sortBy,
    double? Function()? latitude,
    double? Function()? longitude,
    double? Function()? maxDistanceKm,
  }) {
    return VenueSearchQuery(
      query: query ?? this.query,
      categorySlug: categorySlug != null ? categorySlug() : this.categorySlug,
      city: city != null ? city() : this.city,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      sortBy: sortBy ?? this.sortBy,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      maxDistanceKm: maxDistanceKm != null
          ? maxDistanceKm()
          : this.maxDistanceKm,
    );
  }
}

/// Sort order for venue listings.
enum VenueSortBy { relevance, priceAsc, priceDesc, rating, distance }
