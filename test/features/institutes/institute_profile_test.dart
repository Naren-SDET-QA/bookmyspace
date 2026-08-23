import 'package:bookmyspace/features/institutes/domain/institute_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('institute profile hydrates faculty, gallery and courses', () {
    final profile = InstituteProfile.fromJson({
      'id': 'i1',
      'org_id': 'o1',
      'name': 'Nexus Academy',
      'description': 'STEM coaching',
      'is_verified': true,
      'city': 'Guntur',
      'institute_faculty': [
        {
          'id': 'f1',
          'institute_id': 'i1',
          'name': 'Anita Rao',
          'specialization': 'Physics',
          'experience_years': 8,
        },
      ],
      'institute_media': [
        {
          'id': 'm1',
          'url': 'https://example.com/a.jpg',
          'media_kind': 'image',
          'is_cover': true,
        },
      ],
      'courses': [
        {
          'id': 'c1',
          'institute_id': 'i1',
          'title': 'Demo Physics',
          'description': '',
          'mode': 'hybrid',
          'duration_weeks': 4,
          'fee_amount': 0,
          'status': 'published',
          'is_demo': true,
          'seats': 20,
        },
      ],
    });
    expect(profile.faculty, hasLength(1));
    expect(profile.faculty.first.specialization, 'Physics');
    expect(profile.coverUrl, 'https://example.com/a.jpg');
    expect(profile.courses.first.isDemo, isTrue);
    expect(profile.courses.first.mode.name, 'hybrid');
    expect(profile.courses.first.seats, 20);
  });
}
