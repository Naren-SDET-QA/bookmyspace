import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/location/domain/location_node.dart';
import 'package:bookmyspace/features/location/domain/external_location_provider.dart';
import 'package:bookmyspace/features/location/domain/search_area.dart';
import 'package:bookmyspace/features/location/presentation/widgets/cascading_location_selector.dart';
import 'package:bookmyspace/features/location/domain/location_hierarchy_validator.dart';
import 'package:bookmyspace/features/location/domain/location_repository.dart';

void main() {
  test('location node parses global hierarchy levels and coordinates', () {
    final node = LocationNode.fromJson({
      'id': 'city-1',
      'level': 'city_town',
      'country_code': 'US',
      'name': 'Austin',
      'normalized_name': 'austin',
      'latitude': 30.2672,
      'longitude': -97.7431,
      'timezone': 'America/Chicago',
    });

    expect(node.level, LocationNodeLevel.cityTown);
    expect(node.countryCode, 'US');
    expect(node.latitude, 30.2672);
    expect(node.timezone, 'America/Chicago');
  });

  test('search area preserves normalized metadata and radius', () {
    const area = SearchArea(
      label: 'Austin',
      latitude: 30.2672,
      longitude: -97.7431,
      radiusKm: 10,
      locationNodeId: 'city-1',
      countryCode: 'US',
      country: 'United States',
      city: 'Austin',
      timezone: 'America/Chicago',
    );

    expect(area.locationNodeId, 'city-1');
    expect(area.countryCode, 'US');
    expect(area.timezone, 'America/Chicago');
    expect(area.radiusKm, 10);
  });

  test('selecting a parent creates a clean descendant selection', () {
    final country = LocationNode.fromJson({
      'id': 'in',
      'level': 'country',
      'country_code': 'IN',
      'name': 'India',
      'normalized_name': 'india',
    });
    final state = LocationNode.fromJson({
      'id': 'ts',
      'parent_id': 'in',
      'level': 'state_province',
      'country_code': 'IN',
      'name': 'Telangana',
      'normalized_name': 'telangana',
    });
    final oldCity = LocationNode.fromJson({
      'id': 'hyd',
      'parent_id': 'ts',
      'level': 'city_town',
      'country_code': 'IN',
      'name': 'Hyderabad',
      'normalized_name': 'hyderabad',
    });
    final value = CascadingLocationValue(
      country: country,
      state: state,
      city: oldCity,
    );
    final changed = CascadingLocationValue(country: country);

    expect(value.selectedLocationId, 'hyd');
    expect(changed.selectedLocationId, 'in');
    expect(changed.state, isNull);
    expect(changed.city, isNull);
  });

  test('external candidates map to pending suggestion metadata', () {
    const candidate = ExternalLocationCandidate(
      provider: 'test-provider',
      name: 'London',
      country: 'United Kingdom',
      city: 'London',
      postalCode: 'SW1A',
      externalId: 'ext-1',
    );
    expect(locationLevelForCandidate(candidate), LocationNodeLevel.cityTown);
    expect(candidate.toSuggestionPayload()['external_id'], 'ext-1');
    expect(candidate.toSuggestionPayload()['postal_code'], 'SW1A');
  });

  test('parses mandal, village and one-to-many PIN metadata', () {
    final mandal = LocationNode.fromJson({
      'id': 'mandal-1',
      'parent_id': 'district-1',
      'level': 'mandal_taluk_tehsil_block',
      'country_code': 'IN',
      'name': 'Test Mandal',
      'normalized_name': 'test mandal',
      'metadata': {'administrative_type': 'Mandal'},
    });
    final village = LocationNode.fromJson({
      'id': 'village-1',
      'parent_id': 'mandal-1',
      'level': 'village',
      'country_code': 'IN',
      'name': 'Test Village',
      'normalized_name': 'test village',
      'metadata': {
        'postal_codes': ['500001', '500002'],
      },
    });

    expect(mandal.level, LocationNodeLevel.mandalTalukTehsilBlock);
    expect(mandal.metadata['administrative_type'], 'Mandal');
    expect(village.level, LocationNodeLevel.village);
    expect(village.postalCodes, ['500001', '500002']);
  });

  test('hierarchy validator detects orphans and duplicate siblings', () {
    final nodes = [
      LocationNode.fromJson({
        'id': 'state-1',
        'level': 'state_province',
        'country_code': 'IN',
        'name': 'State',
        'normalized_name': 'state',
      }),
      LocationNode.fromJson({
        'id': 'orphan',
        'parent_id': 'missing',
        'level': 'district_county',
        'country_code': 'IN',
        'name': 'Orphan',
        'normalized_name': 'orphan',
      }),
      LocationNode.fromJson({
        'id': 'city-1',
        'parent_id': 'state-1',
        'level': 'city_town',
        'country_code': 'IN',
        'name': 'Same City',
        'normalized_name': 'same city',
      }),
      LocationNode.fromJson({
        'id': 'city-2',
        'parent_id': 'state-1',
        'level': 'city_town',
        'country_code': 'IN',
        'name': 'Same City',
        'normalized_name': 'same city',
      }),
    ];
    final issues = LocationHierarchyValidator.validate(nodes);
    expect(issues.orphans, contains('orphan'));
    expect(issues.duplicateSiblings, contains('state-1/city_town/same city'));
  });

  test(
    'location repository contract supports bounded children and PIN lookup',
    () {
      Future<void> exercise(LocationRepository repository) async {
        await repository.children(
          parentId: 'hyd-d',
          level: LocationNodeLevel.mandalTalukTehsilBlock,
          limit: 20,
          offset: 0,
        );
        await repository.lookupPin('500001', limit: 20, offset: 0);
      }

      expect(exercise, isA<Function>());
      final value = CascadingLocationValue(
        country: LocationNode.fromJson({
          'id': 'in',
          'level': 'country',
          'name': 'India',
          'normalized_name': 'india',
        }),
        state: LocationNode.fromJson({
          'id': 'ts',
          'parent_id': 'in',
          'level': 'state_province',
          'name': 'Telangana',
          'normalized_name': 'telangana',
        }),
        district: LocationNode.fromJson({
          'id': 'hyd-d',
          'parent_id': 'ts',
          'level': 'district_county',
          'name': 'Hyderabad',
          'normalized_name': 'hyderabad',
        }),
        mandal: LocationNode.fromJson({
          'id': 'hyd-m',
          'parent_id': 'hyd-d',
          'level': 'mandal_taluk_tehsil_block',
          'name': 'Shaikpet',
          'normalized_name': 'shaikpet',
        }),
        village: LocationNode.fromJson({
          'id': 'hyd-v',
          'parent_id': 'hyd-m',
          'level': 'village',
          'name': 'Example Village',
          'normalized_name': 'example village',
        }),
      );
      expect(value.selectedLocationId, 'hyd-v');
      expect(value.pathNames, [
        'India',
        'Telangana',
        'Hyderabad',
        'Shaikpet',
        'Example Village',
      ]);
    },
  );
}
