/// Course delivery mode (`course_mode` enum).
enum CourseMode {
  online,
  offline,
  hybrid;

  static CourseMode fromDb(String value) => switch (value) {
    'online' => CourseMode.online,
    'offline' => CourseMode.offline,
    'hybrid' => CourseMode.hybrid,
    _ => CourseMode.offline,
  };

  String get dbValue => name;
}

/// An education institute offering courses (`institutes`).
class Institute {
  const Institute({
    required this.id,
    required this.orgId,
    required this.name,
    this.description = '',
    this.logoImage = '',
    this.isVerified = false,
  });

  final String id;
  final String orgId;
  final String name;
  final String description;
  final String logoImage;
  final bool isVerified;

  factory Institute.fromJson(Map<String, dynamic> json) => Institute(
    id: json['id'] as String? ?? '',
    orgId: json['org_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    logoImage: json['logo_image'] as String? ?? '',
    isVerified: json['is_verified'] as bool? ?? false,
  );
}

/// A published course (`courses`).
class Course {
  const Course({
    required this.id,
    required this.instituteId,
    required this.title,
    required this.description,
    required this.mode,
    required this.durationWeeks,
    required this.feeAmount,
    required this.status,
    this.venueId = '',
    this.instructorName = '',
    this.coverImage = '',
    this.instituteName = '',
    this.instituteVerified = false,
    this.batches = const [],
  });

  final String id;
  final String instituteId;
  final String title;
  final String description;
  final CourseMode mode;
  final String venueId;
  final int durationWeeks;
  final double feeAmount;
  final String instructorName;
  final String coverImage;
  final String status;
  final String instituteName;
  final bool instituteVerified;
  final List<CourseBatch> batches;

  bool get isFree => feeAmount <= 0;

  factory Course.fromJson(Map<String, dynamic> json) {
    final instituteRaw = json['institutes'];
    final institute = instituteRaw is Map<String, dynamic>
        ? instituteRaw
        : <String, dynamic>{};
    final batchesRaw = json['course_batches'];
    final batches = batchesRaw is List
        ? batchesRaw
              .whereType<Map<String, dynamic>>()
              .map(CourseBatch.fromJson)
              .toList()
        : const <CourseBatch>[];
    return Course(
      id: json['id'] as String? ?? '',
      instituteId: json['institute_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mode: CourseMode.fromDb(json['mode'] as String? ?? ''),
      venueId: json['venue_id'] as String? ?? '',
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 1,
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0,
      instructorName: json['instructor_name'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      status: json['status'] as String? ?? 'published',
      instituteName: institute['name'] as String? ?? '',
      instituteVerified: institute['is_verified'] as bool? ?? false,
      batches: batches,
    );
  }
}

/// An enrollable cohort of a course (`course_batches`).
class CourseBatch {
  const CourseBatch({
    required this.id,
    required this.courseId,
    required this.label,
    required this.startsOn,
    required this.capacity,
    required this.enrolledCount,
    this.isActive = true,
    this.userEnrolled = false,
  });

  final String id;
  final String courseId;
  final String label;
  final DateTime startsOn;
  final int capacity;
  final int enrolledCount;
  final bool isActive;
  final bool userEnrolled;

  int get seatsLeft {
    final left = capacity - enrolledCount;
    return left < 0 ? 0 : left;
  }

  bool get isFull => seatsLeft <= 0;

  factory CourseBatch.fromJson(Map<String, dynamic> json) => CourseBatch(
    id: json['id'] as String? ?? '',
    courseId: json['course_id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    startsOn:
        DateTime.tryParse(json['starts_on'] as String? ?? '') ?? DateTime(1970),
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    enrolledCount: (json['enrolled_count'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] as bool? ?? true,
    userEnrolled: json['user_enrolled'] as bool? ?? false,
  );
}
