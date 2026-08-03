import '../domain/course.dart';

/// Contract for the courses feature.
abstract interface class CourseRepository {
  /// Published courses, newest first, with their institute.
  Future<List<Course>> publishedCourses();

  /// A single course with its batches and institute.
  Future<Course> courseDetail(String courseId);

  /// Enrolls the current user into a batch (atomic, capacity-safe).
  Future<void> enroll({required String batchId});

  /// Drops my enrollment from a batch, freeing a seat.
  Future<void> drop({required String batchId});
}
