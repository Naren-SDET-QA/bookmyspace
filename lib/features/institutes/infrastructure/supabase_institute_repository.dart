import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart'
    show mapError, NotFoundException;
import '../../courses/domain/course.dart';
import '../domain/institute_profile.dart';
import '../domain/institute_repository.dart';

class SupabaseInstituteRepository implements InstituteRepository {
  SupabaseInstituteRepository(this._client);

  final SupabaseClient _client;

  static const _select = '''
    *,
    institute_faculty (*),
    institute_media (*),
    courses (*)
  ''';

  @override
  Future<List<InstituteProfile>> publishedInstitutes() async {
    try {
      try {
        final rows = await _client
            .from('institutes')
            .select(_select)
            .eq('is_published', true)
            .order('name');
        return rows
            .whereType<Map<String, dynamic>>()
            .map(InstituteProfile.fromJson)
            .toList();
      } catch (_) {
        final rows = await _client
            .from('institutes')
            .select('*, courses (*)')
            .order('name');
        return rows
            .whereType<Map<String, dynamic>>()
            .map(InstituteProfile.fromJson)
            .toList();
      }
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<InstituteProfile> detail(String instituteId) async {
    try {
      final row = await _client
          .from('institutes')
          .select(_select)
          .eq('id', instituteId)
          .maybeSingle();
      if (row == null) {
        throw const NotFoundException('Institute not found', code: 'not_found');
      }
      return InstituteProfile.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<InstituteProfile?> myInstitute() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final org = await _client
          .from('organizations')
          .select('id')
          .eq('owner_user_id', userId)
          .maybeSingle();
      if (org == null) return null;
      final row = await _client
          .from('institutes')
          .select(_select)
          .eq('org_id', org['id'] as Object)
          .maybeSingle();
      if (row == null) return null;
      return InstituteProfile.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<InstituteProfile> upsertMine({
    required String name,
    required String description,
    String phone = '',
    String whatsapp = '',
    String city = '',
    String address = '',
  }) async {
    try {
      final existing = await myInstitute();
      if (existing != null) {
        final row = await _client
            .from('institutes')
            .update({
              'name': name,
              'description': description,
              'phone': phone,
              'whatsapp': whatsapp,
              'city': city,
              'address': address,
            })
            .eq('id', existing.id)
            .select(_select)
            .single();
        return InstituteProfile.fromJson(row);
      }
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const NotFoundException('Not signed in', code: 'unauthenticated');
      }
      final org = await _client
          .from('organizations')
          .select('id')
          .eq('owner_user_id', userId)
          .maybeSingle();
      if (org == null) {
        throw const NotFoundException(
          'Owner organisation not found',
          code: 'owner_org_not_found',
        );
      }
      final row = await _client
          .from('institutes')
          .insert({
            'org_id': org['id'],
            'name': name,
            'description': description,
            'phone': phone,
            'whatsapp': whatsapp,
            'city': city,
            'address': address,
            'is_published': true,
          })
          .select(_select)
          .single();
      return InstituteProfile.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<FacultyMember> addFaculty({
    required String instituteId,
    required String name,
    String qualification = '',
    String specialization = '',
  }) async {
    try {
      final row = await _client
          .from('institute_faculty')
          .insert({
            'institute_id': instituteId,
            'name': name,
            'qualification': qualification,
            'specialization': specialization,
          })
          .select()
          .single();
      return FacultyMember.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteFaculty(String facultyId) async {
    try {
      await _client.from('institute_faculty').delete().eq('id', facultyId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteClass(String classId) async {
    try {
      await _client.from('courses').delete().eq('id', classId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Course> updateClassStatus(String classId, String status) async {
    try {
      final row = await _client
          .from('courses')
          .update({'status': status})
          .eq('id', classId)
          .select()
          .single();
      return Course.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Course> saveClass({
    required String instituteId,
    String? courseId,
    required OwnerClassDraft draft,
  }) async {
    try {
      final payload = {
        'institute_id': instituteId,
        'title': draft.title,
        'description': draft.description,
        'mode': draft.mode,
        'duration_weeks': draft.durationWeeks,
        'fee_amount': draft.feeAmount,
        'instructor_name': draft.instructorName,
        'is_demo': draft.isDemo,
        'status': draft.status,
        'seats': draft.seats,
        'schedule_notes': draft.scheduleNotes,
      };
      final Map<String, dynamic> row;
      if (courseId == null) {
        row = await _client.from('courses').insert(payload).select().single();
      } else {
        row = await _client
            .from('courses')
            .update(payload)
            .eq('id', courseId)
            .select()
            .single();
      }
      return Course.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }
}
