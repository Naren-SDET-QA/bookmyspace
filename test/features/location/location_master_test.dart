import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/location/domain/location_node.dart';
import 'package:bookmyspace/features/location/domain/external_location_provider.dart';
import 'package:bookmyspace/features/location/domain/search_area.dart';
import 'package:bookmyspace/features/location/presentation/widgets/cascading_location_selector.dart';

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
}
