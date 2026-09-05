import '../../courses/domain/course.dart';
import 'institute_profile.dart';

abstract interface class InstituteRepository {
  Future<List<InstituteProfile>> publishedInstitutes();

  Future<InstituteProfile> detail(String instituteId);

  Future<InstituteProfile?> myInstitute();

  Future<InstituteProfile> upsertMine({
    required String name,
    required String description,
    String phone,
    String whatsapp,
    String city,
    String address,
  });

  Future<FacultyMember> addFaculty({
    required String instituteId,
    required String name,
    String qualification,
    String specialization,
  });

  Future<void> deleteFaculty(String facultyId);

  Future<void> deleteClass(String classId);

  Future<Course> updateClassStatus(String classId, String status);

  Future<Course> saveClass({
    required String instituteId,
    String? courseId,
    required OwnerClassDraft draft,
  });
}
