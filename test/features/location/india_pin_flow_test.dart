import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/features/location/domain/india_location_importer.dart';
import 'package:bookmyspace/features/location/domain/india_location_source_validator.dart';
import 'package:bookmyspace/features/location/domain/india_pin.dart';
import 'package:bookmyspace/features/location/domain/location_hierarchy_validator.dart';
import 'package:bookmyspace/features/location/domain/location_node.dart';
import 'package:bookmyspace/features/location/domain/location_repository.dart';
import 'package:bookmyspace/features/location/domain/search_area.dart';
import 'package:bookmyspace/features/location/infrastructure/india_post_location_source.dart';
import 'package:bookmyspace/features/location/infrastructure/lgd_location_source.dart';
import 'package:bookmyspace/features/location/presentation/location_providers.dart';
import 'package:bookmyspace/features/location/presentation/widgets/cascading_location_selector.dart';
import 'package:bookmyspace/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryLocationRepository implements LocationRepository {
  _MemoryLocationRepository(this.nodes, this.pins);

  final List<LocationNode> nodes;
  final List<({String locationId, String pin})> pins;

  @override
  Future<List<LocationNode>> children({
    String? parentId,
    required LocationNodeLevel level,
    int limit = 50,
    int offset = 0,
  }) async {
    final matches = nodes
        .where((node) => node.parentId == parentId && node.level == level)
        .toList();
    return matches.skip(offset).take(limit).toList();
  }

  @override
  Future<List<LocationNode>> lookupPin(
    String pin, {
    int limit = 50,
    int offset = 0,
  }) async {
    final normalized = IndiaPin.normalize(pin);
    if (normalized == null) return const [];
    final ids = pins
        .where((link) => link.pin == normalized)
        .map((link) => link.locationId)
        .toSet();
    return nodes
        .where((node) => ids.contains(node.id))
        .skip(offset)
        .take(limit)
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
    int limit = 25,
    int offset = 0,
  }) {
    final pin = IndiaPin.normalize(query);
    if (pin != null) return lookupPin(pin, limit: limit, offset: offset);
    return Future.value(
      nodes
          .where(
            (node) =>
                node.name.toLowerCase().contains(query.toLowerCase()) &&
                (countryCode == null || node.countryCode == countryCode) &&
                (level == null || node.level == level),
          )
          .skip(offset)
          .take(limit)
          .toList(),
    );
  }
}

void main() {
  test('country level parses as country, not city', () {
    final node = LocationNode.fromJson({
      'id': 'in',
      'level': 'country',
      'country_code': 'IN',
      'name': 'India',
      'normalized_name': 'india',
    });
    expect(node.level, LocationNodeLevel.country);
  });

  test('PIN helper accepts only 6-digit India PINs', () {
    expect(IndiaPin.isValid('500001'), isTrue);
    expect(IndiaPin.normalize('500 001'), '500001');
    expect(IndiaPin.isValid('50001'), isFalse);
    expect(IndiaPin.isValid('Hyderabad'), isFalse);
    expect(IndiaPin.normalize('abc'), isNull);
  });

  test('PIN lookup returns every location mapped to that PIN', () async {
    final repo = _MemoryLocationRepository(
      [
        LocationNode.fromJson({
          'id': 'loc-a',
          'level': 'area_locality',
          'country_code': 'IN',
          'name': 'Abids',
          'normalized_name': 'abids',
        }),
        LocationNode.fromJson({
          'id': 'loc-b',
          'level': 'area_locality',
          'country_code': 'IN',
          'name': 'Nampally',
          'normalized_name': 'nampally',
        }),
        LocationNode.fromJson({
          'id': 'loc-c',
          'level': 'area_locality',
          'country_code': 'IN',
          'name': 'Other',
          'normalized_name': 'other',
        }),
      ],
      [
        (locationId: 'loc-a', pin: '500001'),
        (locationId: 'loc-b', pin: '500001'),
        (locationId: 'loc-c', pin: '500002'),
      ],
    );

    final matches = await repo.lookupPin('500001');
    expect(matches.map((node) => node.name), ['Abids', 'Nampally']);
    expect(await repo.search('500001'), hasLength(2));
    expect(await repo.search('500001', limit: 1), hasLength(1));
  });

  test('one location can carry multiple PINs', () {
    final node = LocationNode.fromJson({
      'id': 'hyd-sec',
      'level': 'area_locality',
      'country_code': 'IN',
      'name': 'Secunderabad',
      'normalized_name': 'secunderabad',
      'metadata': {
        'postal_codes': ['500003', '500026'],
      },
    });
    expect(node.postalCodes, ['500003', '500026']);
  });

  test(
    'LGD adapter builds India → state → district → mandal → town/village',
    () {
      final nodes = const LgdLocationSource().parse(const [
        {
          'state_code': '36',
          'state_name': 'Telangana',
          'district_code': '536',
          'district_name': 'Hyderabad',
          'subdistrict_code': '04400',
          'subdistrict_name': 'Amberpet',
          'subdistrict_type': 'Mandal',
          'town_code': '802947',
          'town_name': 'Hyderabad',
        },
        {
          'state_code': '36',
          'state_name': 'Telangana',
          'district_code': '537',
          'district_name': 'Rangareddy',
          'subdistrict_code': '04421',
          'subdistrict_name': 'Shamshabad',
          'subdistrict_type': 'Mandal',
          'village_code': '574321',
          'village_name': 'Shamshabad',
        },
      ]);

      expect(
        nodes.any((node) => node.level == LocationNodeLevel.country),
        isTrue,
      );
      expect(
        nodes
            .where((node) => node.level == LocationNodeLevel.stateProvince)
            .map((node) => node.name),
        ['Telangana'],
      );
      expect(
        nodes
            .where((node) => node.level == LocationNodeLevel.districtCounty)
            .map((node) => node.name),
        containsAll(['Hyderabad', 'Rangareddy']),
      );
      expect(
        nodes.where(
          (node) => node.level == LocationNodeLevel.mandalTalukTehsilBlock,
        ),
        isNotEmpty,
      );
      expect(
        nodes.any((node) => node.level == LocationNodeLevel.cityTown),
        isTrue,
      );
      expect(
        nodes.any((node) => node.level == LocationNodeLevel.village),
        isTrue,
      );
      expect(LocationHierarchyValidator.validate(nodes).orphans, isEmpty);
      expect(
        LocationHierarchyValidator.validate(nodes).invalidParents,
        isEmpty,
      );
    },
  );

  test('India Post adapter maps one PIN to every listed office/locality', () {
    final mappings = const IndiaPostLocationSource().parse(const [
      {
        'officename': 'Abids',
        'pincode': '500001',
        'districtname': 'Hyderabad',
        'statename': 'Telangana',
        'taluk': 'Amberpet',
      },
      {
        'officename': 'Nampally',
        'pincode': '500001',
        'districtname': 'Hyderabad',
        'statename': 'Telangana',
        'taluk': 'Amberpet',
      },
      {
        'officename': 'Secunderabad',
        'pincode': '500003',
        'districtname': 'Hyderabad',
        'statename': 'Telangana',
        'taluk': 'Secunderabad',
      },
    ]);

    expect(
      mappings
          .where((item) => item.postalCode == '500001')
          .map((item) => item.locality),
      ['Abids', 'Nampally'],
    );
    expect(
      mappings
          .where((item) => item.locality == 'Secunderabad')
          .map((item) => item.postalCode),
      ['500003'],
    );
  });

  test('importer attaches many PINs without fabricating geography', () {
    final imported = IndiaLocationImporter().import(
      lgdRows: const [
        {
          'state_code': '36',
          'state_name': 'Telangana',
          'district_code': '536',
          'district_name': 'Hyderabad',
          'subdistrict_code': '04400',
          'subdistrict_name': 'Amberpet',
          'subdistrict_type': 'Mandal',
          'town_code': '802947',
          'town_name': 'Hyderabad',
        },
      ],
      pinRows: const [
        {
          'officename': 'Abids',
          'pincode': '500001',
          'districtname': 'Hyderabad',
          'statename': 'Telangana',
          'taluk': 'Amberpet',
        },
        {
          'officename': 'Abids',
          'pincode': '500095',
          'districtname': 'Hyderabad',
          'statename': 'Telangana',
          'taluk': 'Amberpet',
        },
        {
          'officename': 'Invented Hamlet',
          'pincode': '999999',
          'districtname': 'Unknown District',
          'statename': 'Unknown State',
          'taluk': 'Unknown',
        },
      ],
    );

    expect(
      imported.nodes.any((node) => node.name == 'Invented Hamlet'),
      isFalse,
    );
    expect(
      imported.pinLinks.any((link) => link.postalCode == '999999'),
      isFalse,
    );
    final abids = imported.nodes.firstWhere((node) => node.name == 'Abids');
    expect(
      imported.pinLinks
          .where((link) => link.locationId == abids.id)
          .map((link) => link.postalCode),
      containsAll(['500001', '500095']),
    );
  });

  test('source validator rejects invalid PIN and incomplete hierarchy', () {
    expect(
      IndiaLocationSourceValidator.pinRecord({
        'officename': 'Abids',
        'pincode': '12',
        'districtname': 'Hyderabad',
        'statename': 'Telangana',
      }),
      isFalse,
    );
    expect(
      IndiaLocationSourceValidator.lgdRecord({
        'state_name': 'Telangana',
        'town_name': 'Hyderabad',
      }),
      isFalse,
    );
    expect(
      IndiaLocationSourceValidator.lgdRecord({
        'state_code': '36',
        'state_name': 'Telangana',
        'district_code': '536',
        'district_name': 'Hyderabad',
        'town_code': '1',
        'town_name': 'Hyderabad',
      }),
      isTrue,
    );
  });

  testWidgets('hierarchy can be browsed without a PIN', (tester) async {
    final india = LocationNode.fromJson({
      'id': 'in',
      'level': 'country',
      'country_code': 'IN',
      'name': 'India',
      'normalized_name': 'india',
    });
    final repo = _MemoryLocationRepository([india], const []);
    late CascadingLocationValue value = const CascadingLocationValue();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: CascadingLocationSelector(
              value: value,
              onChanged: (next) => value = next,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Country'), findsOneWidget);
    expect(find.text('State / UT'), findsNothing);
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(value.country?.name, 'India');
  });

  testWidgets('PIN search lists every matching location', (tester) async {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    addTearDown(FeatureRegistry.reset);
    final repo = _MemoryLocationRepository(
      [
        LocationNode.fromJson({
          'id': 'loc-a',
          'level': 'area_locality',
          'country_code': 'IN',
          'name': 'Abids',
          'normalized_name': 'abids',
          'latitude': 17.39,
          'longitude': 78.47,
        }),
        LocationNode.fromJson({
          'id': 'loc-b',
          'level': 'area_locality',
          'country_code': 'IN',
          'name': 'Nampally',
          'normalized_name': 'nampally',
          'latitude': 17.38,
          'longitude': 78.46,
        }),
      ],
      [
        (locationId: 'loc-a', pin: '500001'),
        (locationId: 'loc-b', pin: '500001'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => LocationPickerSheet.show(
                  context,
                  initial: SearchArea.defaultArea,
                ),
                child: const Text('open-picker'),
              ),
            ),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-picker'));
    await tester.pumpAndSettle();
    expect(find.text('Country'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '500001');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Abids'), findsWidgets);
    expect(find.text('Nampally'), findsWidgets);
  });
}
