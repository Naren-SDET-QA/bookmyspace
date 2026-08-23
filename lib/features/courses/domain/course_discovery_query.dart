import 'course.dart';

enum CourseModeFilter { all, online, offline, hybrid }

enum CourseOfferFilter { all, demo, paid, free }

/// Client-side discovery filter over published course rows from Supabase.
/// Does not invent courses or enroll the user.
class CourseDiscoveryQuery {
  const CourseDiscoveryQuery({
    this.query = '',
    this.mode = CourseModeFilter.all,
    this.offer = CourseOfferFilter.all,
  });

  final String query;
  final CourseModeFilter mode;
  final CourseOfferFilter offer;

  List<Course> apply(List<Course> courses) {
    final needle = query.trim().toLowerCase();
    return courses.where((course) {
      if (!_matchesMode(course)) return false;
      if (!_matchesOffer(course)) return false;
      if (needle.isEmpty) return true;
      return [
        course.title,
        course.description,
        course.instituteName,
        course.instructorName,
        course.mode.dbValue,
        course.scheduleNotes,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList();
  }

  bool _matchesMode(Course course) {
    return switch (mode) {
      CourseModeFilter.all => true,
      CourseModeFilter.online => course.mode == CourseMode.online,
      CourseModeFilter.offline => course.mode == CourseMode.offline,
      CourseModeFilter.hybrid => course.mode == CourseMode.hybrid,
    };
  }

  bool _matchesOffer(Course course) {
    return switch (offer) {
      CourseOfferFilter.all => true,
      CourseOfferFilter.demo => course.isDemo,
      CourseOfferFilter.paid => !course.isFree && !course.isDemo,
      CourseOfferFilter.free => course.isFree,
    };
  }
}
