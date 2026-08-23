import 'package:bookmyspace/features/institutes/domain/institute_discovery_query.dart';
import 'package:bookmyspace/features/institutes/domain/institute_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const institutes = [
    InstituteProfile(
      id: 'i1',
      orgId: 'o1',
      name: 'Nexus Academy',
      city: 'Guntur',
      isVerified: true,
    ),
    InstituteProfile(
      id: 'i2',
      orgId: 'o2',
      name: 'City Coaching',
      city: 'Hyderabad',
      description: 'Board exam prep',
    ),
  ];

  test('search matches name, city and description', () {
    final visible = const InstituteDiscoveryQuery(
      query: 'hyderabad',
    ).apply(institutes);
    expect(visible.map((i) => i.id), ['i2']);
  });

  test('verified-only hides unpublished-quality rows without inventing data', () {
    final visible = const InstituteDiscoveryQuery(
      verifiedOnly: true,
    ).apply(institutes);
    expect(visible.map((i) => i.id), ['i1']);
  });
}
