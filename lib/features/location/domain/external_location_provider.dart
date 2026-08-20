import 'location_node.dart';

class ExternalLocationCandidate {
  const ExternalLocationCandidate({
    required this.provider,
    required this.name,
    this.country,
    this.state,
    this.district,
    this.city,
    this.area,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.externalId,
    this.externalUrl,
    this.metadata = const {},
  });

  final String provider;
  final String name;
  final String? country;
  final String? state;
  final String? district;
  final String? city;
  final String? area;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? externalId;
  final String? externalUrl;
  final Map<String, dynamic> metadata;
}

abstract interface class ExternalLocationProvider {
  String get providerName;
  Future<List<ExternalLocationCandidate>> search(String query);
}

extension ExternalLocationCandidateMapping on ExternalLocationCandidate {
  Map<String, dynamic> toSuggestionPayload() => {
    'provider': provider,
    'external_id': externalId,
    'external_url': externalUrl,
    'country': country,
    'state': state,
    'district': district,
    'city': city,
    'area': area,
    'postal_code': postalCode,
    'latitude': latitude,
    'longitude': longitude,
    'metadata': metadata,
  };
}

LocationNodeLevel? locationLevelForCandidate(
  ExternalLocationCandidate candidate,
) {
  if (candidate.area != null) return LocationNodeLevel.areaLocality;
  if (candidate.city != null) return LocationNodeLevel.cityTown;
  if (candidate.district != null) return LocationNodeLevel.districtCounty;
  if (candidate.state != null) return LocationNodeLevel.stateProvince;
  if (candidate.country != null) return LocationNodeLevel.country;
  return null;
}
