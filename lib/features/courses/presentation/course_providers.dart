import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import '../infrastructure/supabase_course_repository.dart';

/// Courses repository instance.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseCourseRepository(client);
});

/// Published courses, newest first, with institutes and batches.
final publishedCoursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).publishedCourses();
});

/// A single course with its batches and institute.
final courseDetailProvider = FutureProvider.autoDispose.family<Course, String>((
  ref,
  courseId,
) {
  return ref.watch(courseRepositoryProvider).courseDetail(courseId);
});

/// Enrolls the current user into a batch and refreshes the course caches.
final enrollInCourseProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  batchId,
) async {
  final repo = ref.watch(courseRepositoryProvider);
  await repo.enroll(batchId: batchId);
  ref.invalidate(publishedCoursesProvider);
});

/// Drops my enrollment from a batch and refreshes the course caches.
final dropCourseProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  batchId,
) async {
  final repo = ref.watch(courseRepositoryProvider);
  await repo.drop(batchId: batchId);
  ref.invalidate(publishedCoursesProvider);
});
