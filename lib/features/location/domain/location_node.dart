enum LocationNodeLevel {
  unknown,
  country,
  stateProvince,
  districtCounty,
  mandalTalukTehsilBlock,
  cityTown,
  village,
  areaLocality,
}

class LocationNode {
  const LocationNode({
    required this.id,
    required this.level,
    required this.countryCode,
    required this.name,
    required this.normalizedName,
    this.parentId,
    this.timezone,
    this.latitude,
    this.longitude,
    this.metadata = const {},
    this.status = 'active',
  });

  final String id;
  final String? parentId;
  final LocationNodeLevel level;
  final String countryCode;
  final String name;
  final String normalizedName;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> metadata;
  final String status;

  factory LocationNode.fromJson(Map<String, dynamic> json) => LocationNode(
    id: json['id'] as String? ?? '',
    parentId: json['parent_id'] as String?,
    level: LocationNodeLevel.values.firstWhere(
      (value) => value.name == _levelName(json['level'] as String? ?? ''),
      orElse: () => LocationNodeLevel.cityTown,
    ),
    countryCode: json['country_code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    normalizedName: json['normalized_name'] as String? ?? '',
    timezone: json['timezone'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    metadata: Map<String, dynamic>.from(
      (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    status: json['status'] as String? ?? 'active',
  );

  List<String> get postalCodes {
    final value =
        metadata['postal_codes'] ??
        metadata['pincodes'] ??
        metadata['postal_code'] ??
        metadata['pincode'];
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  static String _levelName(String value) => switch (value) {
    'country' => 'country',
    'state_province' => 'stateProvince',
    'district_county' => 'districtCounty',
    'city_town' => 'cityTown',
    'area_locality' => 'areaLocality',
    'mandal_taluk_tehsil_block' => 'mandalTalukTehsilBlock',
    'village' => 'village',
    _ => 'unknown',
  };
}
