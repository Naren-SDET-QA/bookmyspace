import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseMode', () {
    test('round-trips db values', () {
      for (final mode in CourseMode.values) {
        expect(CourseMode.fromDb(mode.dbValue), mode);
      }
    });

    test('unknown mode falls back to offline', () {
      expect(CourseMode.fromDb('weird'), CourseMode.offline);
    });
  });

  group('Institute', () {
    test('parses a row', () {
      final institute = Institute.fromJson({
        'id': 'i1',
        'org_id': 'o1',
        'name': 'Nexus Learning Institute',
        'is_verified': true,
      });
      expect(institute.name, 'Nexus Learning Institute');
      expect(institute.isVerified, isTrue);
    });
  });

  group('Course', () {
    test('parses a row with embedded institute and batches', () {
      final course = Course.fromJson({
        'id': 'c1',
        'institute_id': 'i1',
        'title': 'Flutter Bootcamp',
        'mode': 'online',
        'duration_weeks': 8,
        'fee_amount': 29999,
        'instructor_name': 'Anand Kumar',
        'status': 'published',
        'institutes': {'name': 'Nexus Learning Institute', 'is_verified': true},
        'course_batches': [
          {
            'id': 'b1',
            'course_id': 'c1',
            'label': 'Weekday Batch A',
            'starts_on': '2026-08-10',
            'capacity': 25,
            'enrolled_count': 3,
            'is_active': true,
          },
        ],
      });
      expect(course.mode, CourseMode.online);
      expect(course.instituteName, 'Nexus Learning Institute');
      expect(course.batches, hasLength(1));
      expect(course.batches.first.seatsLeft, 22);
    });

    test('isFree reflects a zero fee', () {
      const free = Course(
        id: 'c1',
        instituteId: 'i1',
        title: 'Free Course',
        description: '',
        mode: CourseMode.online,
        durationWeeks: 4,
        feeAmount: 0,
        status: 'published',
      );
      expect(free.isFree, isTrue);
    });
  });

  group('CourseBatch', () {
    test('isFull reflects capacity vs enrolled count', () {
      final full = CourseBatch.fromJson({
        'id': 'b1',
        'course_id': 'c1',
        'label': 'A',
        'starts_on': '2026-08-10',
        'capacity': 25,
        'enrolled_count': 25,
      });
      expect(full.isFull, isTrue);
      expect(full.seatsLeft, 0);
    });

    test('user_enrolled is parsed', () {
      final batch = CourseBatch.fromJson({
        'id': 'b1',
        'course_id': 'c1',
        'label': 'A',
        'starts_on': '2026-08-10',
        'capacity': 25,
        'enrolled_count': 1,
        'user_enrolled': true,
      });
      expect(batch.userEnrolled, isTrue);
    });
  });
}
