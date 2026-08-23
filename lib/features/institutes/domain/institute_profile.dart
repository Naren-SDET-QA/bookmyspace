import '../../courses/domain/course.dart';

class FacultyMember {
  const FacultyMember({
    required this.id,
    required this.instituteId,
    required this.name,
    this.qualification = '',
    this.experienceYears = 0,
    this.specialization = '',
    this.photoUrl = '',
    this.bio = '',
  });

  final String id;
  final String instituteId;
  final String name;
  final String qualification;
  final int experienceYears;
  final String specialization;
  final String photoUrl;
  final String bio;

  factory FacultyMember.fromJson(Map<String, dynamic> json) => FacultyMember(
    id: json['id'] as String? ?? '',
    instituteId: json['institute_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    qualification: json['qualification'] as String? ?? '',
    experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
    specialization: json['specialization'] as String? ?? '',
    photoUrl: json['photo_url'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
  );
}

class InstituteMedia {
  const InstituteMedia({
    required this.id,
    required this.url,
    this.thumbnailUrl = '',
    this.altText = '',
    this.mediaKind = 'image',
    this.isCover = false,
  });

  final String id;
  final String url;
  final String thumbnailUrl;
  final String altText;
  final String mediaKind;
  final bool isCover;

  factory InstituteMedia.fromJson(Map<String, dynamic> json) => InstituteMedia(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    altText: json['alt_text'] as String? ?? '',
    mediaKind: json['media_kind'] as String? ?? 'image',
    isCover: json['is_cover'] as bool? ?? false,
  );
}

class InstituteProfile {
  const InstituteProfile({
    required this.id,
    required this.orgId,
    required this.name,
    this.description = '',
    this.logoImage = '',
    this.isVerified = false,
    this.isPublished = true,
    this.phone = '',
    this.whatsapp = '',
    this.websiteUrl = '',
    this.instagramUrl = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.faculty = const [],
    this.media = const [],
    this.courses = const [],
  });

  final String id;
  final String orgId;
  final String name;
  final String description;
  final String logoImage;
  final bool isVerified;
  final bool isPublished;
  final String phone;
  final String whatsapp;
  final String websiteUrl;
  final String instagramUrl;
  final String address;
  final String city;
  final String state;
  final List<FacultyMember> faculty;
  final List<InstituteMedia> media;
  final List<Course> courses;

  String get coverUrl {
    for (final item in media) {
      if (item.isCover && item.url.isNotEmpty) return item.url;
    }
    if (media.isNotEmpty) return media.first.url;
    return logoImage;
  }

  factory InstituteProfile.fromJson(Map<String, dynamic> json) {
    final facultyRaw = json['institute_faculty'];
    final mediaRaw = json['institute_media'];
    final coursesRaw = json['courses'];
    return InstituteProfile(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logoImage: json['logo_image'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      websiteUrl: json['website_url'] as String? ?? '',
      instagramUrl: json['instagram_url'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      faculty: facultyRaw is List
          ? facultyRaw
                .whereType<Map<String, dynamic>>()
                .map(FacultyMember.fromJson)
                .toList()
          : const [],
      media: mediaRaw is List
          ? mediaRaw
                .whereType<Map<String, dynamic>>()
                .map(InstituteMedia.fromJson)
                .toList()
          : const [],
      courses: coursesRaw is List
          ? coursesRaw
                .whereType<Map<String, dynamic>>()
                .map(Course.fromJson)
                .toList()
          : const [],
    );
  }
}

class OwnerClassDraft {
  const OwnerClassDraft({
    required this.title,
    required this.description,
    required this.mode,
    required this.durationWeeks,
    required this.feeAmount,
    this.instructorName = '',
    this.isDemo = false,
    this.status = 'draft',
    this.seats,
    this.scheduleNotes = '',
  });

  final String title;
  final String description;
  final String mode;
  final int durationWeeks;
  final double feeAmount;
  final String instructorName;
  final bool isDemo;
  final String status;
  final int? seats;
  final String scheduleNotes;
}
