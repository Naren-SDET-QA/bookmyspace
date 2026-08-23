import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/course_discovery_query.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course({
  required String id,
  required String title,
  CourseMode mode = CourseMode.offline,
  double feeAmount = 29999,
  bool isDemo = false,
  String instituteName = 'Nexus Learning Institute',
}) {
  return Course(
    id: id,
    instituteId: 'i1',
    title: title,
    description: '$title description',
    mode: mode,
    durationWeeks: 8,
    feeAmount: feeAmount,
    status: 'published',
    instructorName: 'Anand Kumar',
    instituteName: instituteName,
    isDemo: isDemo,
  );
}

void main() {
  final courses = [
    _course(id: 'c1', title: 'Flutter Bootcamp'),
    _course(
      id: 'c2',
      title: 'Online Python',
      mode: CourseMode.online,
      feeAmount: 0,
    ),
    _course(
      id: 'c3',
      title: 'Demo Physics',
      mode: CourseMode.hybrid,
      isDemo: true,
      feeAmount: 0,
      instituteName: 'Guntur STEM Academy',
    ),
  ];

  test('search matches title and institute', () {
    final visible = const CourseDiscoveryQuery(query: 'guntur').apply(courses);
    expect(visible.map((c) => c.id), ['c3']);
  });

  test('mode and offer filters compose', () {
    final online = const CourseDiscoveryQuery(
      mode: CourseModeFilter.online,
    ).apply(courses);
    expect(online.map((c) => c.id), ['c2']);

    final demo = const CourseDiscoveryQuery(
      offer: CourseOfferFilter.demo,
    ).apply(courses);
    expect(demo.map((c) => c.id), ['c3']);

    final paid = const CourseDiscoveryQuery(
      offer: CourseOfferFilter.paid,
    ).apply(courses);
    expect(paid.map((c) => c.id), ['c1']);
  });
}
