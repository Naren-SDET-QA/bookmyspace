import 'package:bookmyspace/features/location/domain/india_location_importer.dart';
import 'package:bookmyspace/features/location/domain/india_location_source_validator.dart';
import 'package:bookmyspace/features/location/domain/india_pin.dart';
import 'package:bookmyspace/features/location/domain/location_hierarchy_validator.dart';
import 'package:bookmyspace/features/location/domain/location_node.dart';
import 'package:bookmyspace/features/location/domain/location_query_bounds.dart';
import 'package:bookmyspace/features/location/domain/location_repository.dart';
import 'package:bookmyspace/features/location/infrastructure/geonames_location_source.dart';
import 'package:bookmyspace/features/location/infrastructure/lgd_location_source.dart';
import 'package:bookmyspace/features/location/presentation/widgets/cascading_location_selector.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagedLocationRepository implements LocationRepository {
  _PagedLocationRepository(this.nodes, this.pins);

  final List<LocationNode> nodes;
  final List<({String locationId, String pin})> pins;

  @override
  Future<List<LocationNode>> children({
    String? parentId,
    required LocationNodeLevel level,
    int limit = LocationQueryBounds.childrenPageSize,
    int offset = 0,
  }) async {
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.childrenPageSize,
    );
    return nodes
        .where((node) => node.parentId == parentId && node.level == level)
        .skip(offset)
        .take(bounded)
        .toList();
  }

  @override
  Future<List<LocationNode>> lookupPin(
    String pin, {
    int limit = LocationQueryBounds.pinPageSize,
    int offset = 0,
  }) async {
    final normalized = IndiaPin.normalize(pin);
    if (normalized == null) return const [];
    final ids = pins
        .where((link) => link.pin == normalized)
        .map((link) => link.locationId)
        .toSet();
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.pinPageSize,
    );
    return nodes
        .where((node) => ids.contains(node.id))
        .skip(offset)
        .take(bounded)
        .toList();
  }

  @override
  Future<List<LocationNode>> path(String locationId) async {
    final byId = {for (final node in nodes) node.id: node};
    final result = <LocationNode>[];
    String? current = locationId;
    while (current != null) {
      final node = byId[current];
      if (node == null) break;
      result.add(node);
      current = node.parentId;
    }
    return result.reversed.toList();
  }

  @override
  Future<List<LocationNode>> search(
    String query, {
    String? countryCode,
    LocationNodeLevel? level,
    int limit = LocationQueryBounds.searchPageSize,
    int offset = 0,
  }) {
    final pin = IndiaPin.normalize(query);
    if (pin != null) {
      return lookupPin(pin, limit: limit, offset: offset);
    }
    final needle = query.toLowerCase();
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.searchPageSize,
    );
    return Future.value(
      nodes
          .where((node) {
            final nameHit =
                node.name.toLowerCase().contains(needle) ||
                node.normalizedName.contains(needle);
            final countryHit =
                countryCode == null || node.countryCode == countryCode;
            final levelHit = level == null || node.level == level;
            return nameHit && countryHit && levelHit;
          })
          .skip(offset)
          .take(bounded)
          .toList(),
    );
  }
}

LocationNode _node({
  required String id,
  required String level,
  required String name,
  String? parentId,
  String countryCode = 'IN',
}) {
  return LocationNode.fromJson({
    'id': id,
    'parent_id': parentId,
    'level': level,
    'country_code': countryCode,
    'name': name,
    'normalized_name': name.toLowerCase(),
  });
}

void main() {
  final india = _node(id: 'in', level: 'country', name: 'India');
  final telangana = _node(
    id: 'in-st-36',
    parentId: 'in',
    level: 'state_province',
    name: 'Telangana',
  );
  final hyderabadDistrict = _node(
    id: 'in-dt-536',
    parentId: 'in-st-36',
    level: 'district_county',
    name: 'Hyderabad',
  );
  final amberpet = _node(
    id: 'in-sd-04400',
    parentId: 'in-dt-536',
    level: 'mandal_taluk_tehsil_block',
    name: 'Amberpet',
  );
  final hyderabadTown = _node(
    id: 'in-tn-802947',
    parentId: 'in-sd-04400',
    level: 'city_town',
    name: 'Hyderabad',
  );
  final shamshabadVillage = _node(
    id: 'in-vl-574321',
    parentId: 'in-sd-04400',
    level: 'village',
    name: 'Shamshabad',
  );
  final abids = _node(
    id: 'in-lc-abids',
    parentId: 'in-tn-802947',
    level: 'area_locality',
    name: 'Abids',
  );
  final nampally = _node(
    id: 'in-lc-nampally',
    parentId: 'in-tn-802947',
    level: 'area_locality',
    name: 'Nampally',
  );

  late _PagedLocationRepository repo;

  setUp(() {
    repo = _PagedLocationRepository(
      [
        india,
        telangana,
        hyderabadDistrict,
        amberpet,
        hyderabadTown,
        shamshabadVillage,
        abids,
        nampally,
      ],
      [
        (locationId: 'in-lc-abids', pin: '500001'),
        (locationId: 'in-lc-nampally', pin: '500001'),
        (locationId: 'in-lc-abids', pin: '500095'),
      ],
    );
  });

  test('State → District children resolve from the parent only', () async {
    final districts = await repo.children(
      parentId: telangana.id,
      level: LocationNodeLevel.districtCounty,
    );
    expect(districts.map((node) => node.name), ['Hyderabad']);
  });

  test('a search result hydrates the complete selectable location path', () {
    final value = CascadingLocationValue.fromPath([
      india,
      telangana,
      hyderabadDistrict,
      amberpet,
      hyderabadTown,
      abids,
    ]);

    expect(value.country?.id, india.id);
    expect(value.state?.id, telangana.id);
    expect(value.district?.id, hyderabadDistrict.id);
    expect(value.mandal?.id, amberpet.id);
    expect(value.city?.id, hyderabadTown.id);
    expect(value.area?.id, abids.id);
    expect(value.selectedLocationId, abids.id);
  });

  test('District → Mandal children resolve from the parent only', () async {
    final mandals = await repo.children(
      parentId: hyderabadDistrict.id,
      level: LocationNodeLevel.mandalTalukTehsilBlock,
    );
    expect(mandals.map((node) => node.name), ['Amberpet']);
  });

  test('Mandal → Town/Village children are siblings', () async {
    final towns = await repo.children(
      parentId: amberpet.id,
      level: LocationNodeLevel.cityTown,
    );
    final villages = await repo.children(
      parentId: amberpet.id,
      level: LocationNodeLevel.village,
    );
    expect(towns.map((node) => node.name), ['Hyderabad']);
    expect(villages.map((node) => node.name), ['Shamshabad']);
  });

  test('Town/Village → Locality children stay under the settlement', () async {
    final localities = await repo.children(
      parentId: hyderabadTown.id,
      level: LocationNodeLevel.areaLocality,
    );
    expect(localities.map((node) => node.name), ['Abids', 'Nampally']);
  });

  test(
    'search finds state, district, mandal, town, village and locality',
    () async {
      expect(
        (await repo.search(
          'Telangana',
          level: LocationNodeLevel.stateProvince,
        )).single.name,
        'Telangana',
      );
      expect(
        (await repo.search(
          'Hyderabad',
          level: LocationNodeLevel.districtCounty,
        )).single.id,
        hyderabadDistrict.id,
      );
      expect(
        (await repo.search(
          'Amberpet',
          level: LocationNodeLevel.mandalTalukTehsilBlock,
        )).single.name,
        'Amberpet',
      );
      expect(
        (await repo.search(
          'Hyderabad',
          level: LocationNodeLevel.cityTown,
        )).single.id,
        hyderabadTown.id,
      );
      expect(
        (await repo.search(
          'Shamshabad',
          level: LocationNodeLevel.village,
        )).single.name,
        'Shamshabad',
      );
      expect(
        (await repo.search(
          'Abids',
          level: LocationNodeLevel.areaLocality,
        )).single.name,
        'Abids',
      );
    },
  );

  test('PIN lookup is paginated and invalid PINs return nothing', () async {
    expect(await repo.lookupPin('12'), isEmpty);
    expect(await repo.lookupPin('Hyderabad'), isEmpty);
    final page = await repo.search('500001', limit: 1, offset: 0);
    expect(page, hasLength(1));
    final next = await repo.search('500001', limit: 1, offset: 1);
    expect(next, hasLength(1));
    expect(page.single.id, isNot(next.single.id));
  });

  test('children and search clamp to bounded pages', () async {
    final many = [
      for (var i = 0; i < 80; i++)
        _node(
          id: 'm-$i',
          parentId: hyderabadDistrict.id,
          level: 'mandal_taluk_tehsil_block',
          name: 'Mandal $i',
        ),
    ];
    final paged = _PagedLocationRepository(many, const []);
    final children = await paged.children(
      parentId: hyderabadDistrict.id,
      level: LocationNodeLevel.mandalTalukTehsilBlock,
      limit: 10000,
    );
    expect(children.length, LocationQueryBounds.childrenPageSize);

    final named = [
      for (var i = 0; i < 40; i++)
        _node(id: 's-$i', level: 'state_province', name: 'StateHit $i'),
    ];
    final searchRepo = _PagedLocationRepository(named, const []);
    final hits = await searchRepo.search('StateHit', limit: 999);
    expect(hits.length, LocationQueryBounds.searchPageSize);
    expect(LocationQueryBounds.clamp(0, cap: 25), 1);
  });

  test('LGD may skip mandal and still attach town under district', () {
    final nodes = const LgdLocationSource().parse(const [
      {
        'state_code': '36',
        'state_name': 'Telangana',
        'district_code': '536',
        'district_name': 'Hyderabad',
        'town_code': '802947',
        'town_name': 'Hyderabad',
        'circle_name': 'Unknown future admin unit',
      },
    ]);
    final town = nodes.firstWhere(
      (node) => node.level == LocationNodeLevel.cityTown,
    );
    final district = nodes.firstWhere(
      (node) => node.level == LocationNodeLevel.districtCounty,
    );
    expect(town.parentId, district.id);
    expect(LocationHierarchyValidator.validate(nodes).invalidParents, isEmpty);
  });

  test('unknown extra source columns do not break the importer', () {
    expect(
      IndiaLocationSourceValidator.lgdRecord({
        'state_code': '36',
        'state_name': 'Telangana',
        'district_code': '536',
        'district_name': 'Hyderabad',
        'new_admin_level': 'circle',
      }),
      isTrue,
    );
    final imported = IndiaLocationImporter().import(
      lgdRows: const [
        {
          'state_code': '36',
          'state_name': 'Telangana',
          'district_code': '536',
          'district_name': 'Hyderabad',
          'subdistrict_code': '04400',
          'subdistrict_name': 'Amberpet',
          'subdistrict_type': 'Circle',
          'future_column': 'ignore-me',
        },
      ],
      pinRows: const [],
    );
    expect(
      imported.nodes.any(
        (node) => node.level == LocationNodeLevel.mandalTalukTehsilBlock,
      ),
      isTrue,
    );
    expect(
      imported.nodes.any((node) => node.level == LocationNodeLevel.unknown),
      isFalse,
    );
  });

  test('source-less dry-run does not fabricate geography', () {
    final result = IndiaLocationImporter().dryRun();
    expect(result.sourcesMissing, isTrue);
    expect(result.nodes, isEmpty);
    expect(result.pinLinks, isEmpty);
  });

  test('re-import preserves existing location IDs', () {
    final existing = [
      _node(id: 'keep-in', level: 'country', name: 'India'),
      _node(
        id: 'keep-ts',
        parentId: 'keep-in',
        level: 'state_province',
        name: 'Telangana',
      ),
    ];
    final imported = IndiaLocationImporter().import(
      existingNodes: existing,
      lgdRows: const [
        {
          'state_code': '36',
          'state_name': 'Telangana',
          'district_code': '536',
          'district_name': 'Hyderabad',
          'town_code': '802947',
          'town_name': 'Hyderabad',
        },
      ],
      pinRows: const [],
    );
    expect(
      imported.nodes.firstWhere((node) => node.name == 'India').id,
      'keep-in',
    );
    expect(
      imported.nodes.firstWhere((node) => node.name == 'Telangana').id,
      'keep-ts',
    );
    expect(
      imported.nodes
          .firstWhere((node) => node.level == LocationNodeLevel.districtCounty)
          .parentId,
      'keep-ts',
    );
  });

  test('GeoNames enriches existing nodes and never creates geography', () {
    final enriched = const GeoNamesLocationSource().enrich(
      nodes: [hyderabadTown],
      rows: const [
        {
          'name': 'Hyderabad',
          'admin1': 'Telangana',
          'lat': '17.385',
          'lng': '78.486',
          'timezone': 'Asia/Kolkata',
        },
        {'name': 'Invented Place', 'admin1': 'Nowhere', 'lat': '1', 'lng': '2'},
      ],
    );
    expect(enriched, hasLength(1));
    expect(enriched.single.id, hyderabadTown.id);
    expect(enriched.single.latitude, 17.385);
    expect(enriched.single.longitude, 78.486);
    expect(enriched.any((node) => node.name == 'Invented Place'), isFalse);
  });

  test('legacy country → state → city → locality remains valid', () {
    final nodes = [
      _node(id: 'in', level: 'country', name: 'India'),
      _node(
        id: 'ts',
        parentId: 'in',
        level: 'state_province',
        name: 'Telangana',
      ),
      _node(id: 'hyd', parentId: 'ts', level: 'city_town', name: 'Hyderabad'),
      _node(
        id: 'madhapur',
        parentId: 'hyd',
        level: 'area_locality',
        name: 'Madhapur',
      ),
    ];
    final issues = LocationHierarchyValidator.validate(nodes);
    expect(issues.orphans, isEmpty);
    expect(issues.invalidParents, isEmpty);
  });

  test('invalid hierarchy parent is reported', () {
    final issues = LocationHierarchyValidator.validate([
      _node(id: 'in', level: 'country', name: 'India'),
      _node(
        id: 'bad',
        parentId: 'in',
        level: 'area_locality',
        name: 'Orphan Locality',
      ),
    ]);
    expect(issues.invalidParents, contains('bad'));
  });

  test('categories stay independent from location types', () {
    const category = CategoryConfiguration(
      id: 'cat-1',
      slug: 'function-hall',
      name: 'Function Hall',
    );
    expect(category.slug, 'function-hall');
    expect(
      LocationNodeLevel.values.map((value) => value.name),
      isNot(contains('category')),
    );
  });
}
