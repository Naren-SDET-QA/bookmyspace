import 'location_node.dart';

class LocationHierarchyIssues {
  const LocationHierarchyIssues({
    this.orphans = const [],
    this.duplicateSiblings = const [],
    this.invalidParents = const [],
    this.invalidLevels = const [],
  });

  final List<String> orphans;
  final List<String> duplicateSiblings;
  final List<String> invalidParents;
  final List<String> invalidLevels;
}

/// Read-only validation for normalized source records and synthetic fixtures.
class LocationHierarchyValidator {
  static LocationHierarchyIssues validate(List<LocationNode> nodes) {
    final byId = {for (final node in nodes) node.id: node};
    final orphans = <String>[];
    final invalidParents = <String>[];
    final invalidLevels = <String>[];
    final siblings = <String, String>{};
    final duplicateSiblings = <String>[];

    for (final node in nodes) {
      final parent = node.parentId == null ? null : byId[node.parentId];
      if (node.parentId != null && parent == null) {
        orphans.add(node.id);
      }
      if (node.level == LocationNodeLevel.unknown) {
        invalidLevels.add(node.id);
      }
      if (parent != null && !_allows(parent.level, node.level)) {
        invalidParents.add(node.id);
      }
      final key =
          '${node.parentId}/${_levelValue(node.level)}/${node.normalizedName}';
      if (siblings.containsKey(key)) duplicateSiblings.add(key);
      siblings[key] = node.id;
    }
    return LocationHierarchyIssues(
      orphans: List.unmodifiable(orphans),
      duplicateSiblings: List.unmodifiable(duplicateSiblings),
      invalidParents: List.unmodifiable(invalidParents),
      invalidLevels: List.unmodifiable(invalidLevels),
    );
  }

  static bool _allows(LocationNodeLevel parent, LocationNodeLevel child) {
    return switch (parent) {
      LocationNodeLevel.country => child == LocationNodeLevel.stateProvince,
      LocationNodeLevel.stateProvince =>
        child == LocationNodeLevel.districtCounty ||
            child == LocationNodeLevel.cityTown,
      LocationNodeLevel.districtCounty =>
        child == LocationNodeLevel.mandalTalukTehsilBlock ||
            child == LocationNodeLevel.cityTown ||
            child == LocationNodeLevel.village,
      LocationNodeLevel.mandalTalukTehsilBlock =>
        child == LocationNodeLevel.cityTown ||
            child == LocationNodeLevel.village,
      LocationNodeLevel.cityTown ||
      LocationNodeLevel.village => child == LocationNodeLevel.areaLocality,
      LocationNodeLevel.areaLocality || LocationNodeLevel.unknown => false,
    };
  }

  static String _levelValue(LocationNodeLevel level) => switch (level) {
    LocationNodeLevel.unknown => 'unknown',
    LocationNodeLevel.country => 'country',
    LocationNodeLevel.stateProvince => 'state_province',
    LocationNodeLevel.districtCounty => 'district_county',
    LocationNodeLevel.mandalTalukTehsilBlock => 'mandal_taluk_tehsil_block',
    LocationNodeLevel.cityTown => 'city_town',
    LocationNodeLevel.village => 'village',
    LocationNodeLevel.areaLocality => 'area_locality',
  };
}
