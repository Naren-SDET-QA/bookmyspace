enum LocationNodeLevel {
  country,
  stateProvince,
  districtCounty,
  cityTown,
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
    status: json['status'] as String? ?? 'active',
  );

  static String _levelName(String value) => switch (value) {
    'state_province' => 'stateProvince',
    'district_county' => 'districtCounty',
    'city_town' => 'cityTown',
    'area_locality' => 'areaLocality',
    _ => value,
  };
}
