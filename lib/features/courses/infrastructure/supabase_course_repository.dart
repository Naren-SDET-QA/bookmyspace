import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/course.dart';
import '../domain/course_repository.dart';

/// Supabase-backed [CourseRepository].
///
/// Courses and batches are publicly readable; the current user's batch
/// enrollments are merged in from the security-definer `my_enrolled_batches`
/// RPC so `user_enrolled` is accurate without leaking other users' data.
class SupabaseCourseRepository implements CourseRepository {
  SupabaseCourseRepository(this._client);

  final SupabaseClient _client;

  static const String _courseSelect = '''
    *,
    institutes (id, org_id, name, description, logo_image, is_verified),
    course_batches (id, course_id, label, starts_on, capacity, enrolled_count, is_active)
  ''';

  String? get _userId => _client.auth.currentUser?.id;

  Future<Set<String>> _myEnrolledBatchIds() async {
    final userId = _userId;
    if (userId == null) return const {};
    final rows = await _client.rpc<List<dynamic>>(
      'my_enrolled_batches',
      params: {'p_user_id': userId},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map((r) => (r['batch_id'] ?? '').toString())
        .toSet();
  }

  @override
  Future<List<Course>> publishedCourses() async {
    try {
      final enrolled = await _myEnrolledBatchIds();
      final rows = await _client
          .from('courses')
          .select(_courseSelect)
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map((row) => _mergeEnrollments(Course.fromJson(row), enrolled))
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Course> courseDetail(String courseId) async {
    try {
      final enrolled = await _myEnrolledBatchIds();
      final row = await _client
          .from('courses')
          .select(_courseSelect)
          .eq('id', courseId)
          .maybeSingle();
      if (row == null) {
        throw const app_errors.NotFoundException(
          'Course not found',
          code: 'not_found',
        );
      }
      return _mergeEnrollments(Course.fromJson(row), enrolled);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const app_errors.NotFoundException(
          'Course not found',
          code: 'not_found',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> enroll({required String batchId}) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      await _client.rpc<void>(
        'enroll_in_course',
        params: {'p_batch_id': batchId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('batch full')) {
        throw const app_errors.BusinessException(
          'This batch is full.',
          code: 'batch_full',
        );
      }
      if (message.contains('batch not available')) {
        throw const app_errors.BusinessException(
          'This batch is no longer accepting enrollments.',
          code: 'batch_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> drop({required String batchId}) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      await _client.rpc<void>(
        'drop_course_enrollment',
        params: {'p_batch_id': batchId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  Course _mergeEnrollments(Course course, Set<String> enrolled) {
    final batches = course.batches.map((b) {
      if (!b.userEnrolled && enrolled.contains(b.id)) {
        return CourseBatch(
          id: b.id,
          courseId: b.courseId,
          label: b.label,
          startsOn: b.startsOn,
          capacity: b.capacity,
          enrolledCount: b.enrolledCount,
          isActive: b.isActive,
          userEnrolled: true,
        );
      }
      return b;
    }).toList();
    return Course(
      id: course.id,
      instituteId: course.instituteId,
      title: course.title,
      description: course.description,
      mode: course.mode,
      venueId: course.venueId,
      durationWeeks: course.durationWeeks,
      feeAmount: course.feeAmount,
      instructorName: course.instructorName,
      coverImage: course.coverImage,
      status: course.status,
      instituteName: course.instituteName,
      instituteVerified: course.instituteVerified,
      batches: batches,
    );
  }
}
