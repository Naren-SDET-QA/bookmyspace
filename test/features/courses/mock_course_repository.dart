import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/course_repository.dart';

/// In-memory course repository for tests and widget tests.
class MockCourseRepository implements CourseRepository {
  MockCourseRepository();

  List<Course> courses = const [];
  bool failList = false;
  bool failDetail = false;
  bool failEnroll = false;
  bool failDrop = false;

  String? lastEnrollBatchId;
  String? lastDropBatchId;

  static Course sampleCourse({
    String id = 'c1',
    String title = 'Flutter App Development Bootcamp',
    int batchCount = 2,
  }) {
    return Course(
      id: id,
      instituteId: 'i1',
      title: title,
      description: 'Build and ship production Flutter apps in 8 weeks.',
      mode: CourseMode.offline,
      durationWeeks: 8,
      feeAmount: 29999,
      instructorName: 'Anand Kumar',
      coverImage: 'https://example.com/cover.jpg',
      status: 'published',
      instituteName: 'Nexus Learning Institute',
      instituteVerified: true,
      batches: List.generate(batchCount, (i) {
        return CourseBatch(
          id: 'b$i',
          courseId: id,
          label: i == 0 ? 'Weekday Batch A' : 'Weekend Batch B',
          startsOn: DateTime.now().add(Duration(days: 7 * (i + 1))),
          capacity: 25,
          enrolledCount: i == 0 ? 3 : 20,
          isActive: true,
        );
      }),
    );
  }

  @override
  Future<List<Course>> publishedCourses() async {
    if (failList) throw Exception('list failed');
    return courses;
  }

  @override
  Future<Course> courseDetail(String courseId) async {
    if (failDetail) throw Exception('detail failed');
    return courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => sampleCourse(),
    );
  }

  @override
  Future<void> enroll({required String batchId}) async {
    if (failEnroll) throw Exception('enroll failed');
    lastEnrollBatchId = batchId;
    calls.add('enroll:$batchId');
  }

  final List<String> calls = [];

  @override
  Future<void> drop({required String batchId}) async {
    if (failDrop) throw Exception('drop failed');
    lastDropBatchId = batchId;
    calls.add('drop:$batchId');
  }
}
