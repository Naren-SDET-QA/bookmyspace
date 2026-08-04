import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/accommodation.dart';
import '../domain/accommodation_repository.dart';

class SupabaseAccommodationRepository implements AccommodationRepository {
  SupabaseAccommodationRepository(this._client);

  final SupabaseClient _client;
  static const _selection =
      '*, accommodation_units!accommodation_units_property_id_fkey(*)';

  @override
  Future<List<AccommodationProperty>> search(AccommodationQuery query) async {
    try {
      var request = _client
          .from('accommodation_properties')
          .select(_selection)
          .eq('module', query.module.name)
          .eq('is_active', true);
      if (query.search.trim().isNotEmpty) {
        final value = query.search.trim().replaceAll(',', ' ');
        request = request.or('name.ilike.%$value%,city.ilike.%$value%');
      }
      if (query.type != null && query.type!.isNotEmpty) {
        request = request.eq('property_type', query.type!);
      }
      final rows = await request.order('created_at', ascending: false);
      return rows.map(AccommodationProperty.fromJson).toList();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<AccommodationProperty> detail(String propertyId) async {
    try {
      final row = await _client
          .from('accommodation_properties')
          .select(_selection)
          .eq('id', propertyId)
          .eq('is_active', true)
          .single();
      return AccommodationProperty.fromJson(row);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<String> scheduleVisit({
    required String propertyId,
    required DateTime visitAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      final row = await _client
          .from('accommodation_visits')
          .insert({
            'user_id': userId,
            'property_id': propertyId,
            'visit_at': visitAt.toUtc().toIso8601String(),
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<String> reserve(AccommodationReservationRequest request) async {
    try {
      final format = DateFormat('yyyy-MM-dd');
      if (request.rooms.isNotEmpty) {
        return await _client.rpc<String>(
          'create_stay_booking',
          params: {
            'p_property_id': request.propertyId,
            'p_check_in': format.format(request.checkIn!),
            'p_check_out': format.format(request.checkOut!),
            'p_adults': request.guests,
            'p_children': request.children,
            'p_rooms': request.rooms.map((room) => room.toJson()).toList(),
            'p_idempotency_key': request.idempotencyKey,
            'p_registration_submission_id': request.registrationSubmissionId,
          },
        );
      }
      return await _client.rpc<String>(
        'reserve_accommodation',
        params: {
          'p_property_id': request.propertyId,
          'p_unit_id': request.unitId,
          'p_move_in': request.moveIn == null
              ? null
              : format.format(request.moveIn!),
          'p_check_in': request.checkIn == null
              ? null
              : format.format(request.checkIn!),
          'p_check_out': request.checkOut == null
              ? null
              : format.format(request.checkOut!),
          'p_guests': request.guests,
        },
      );
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<List<StayUnitAvailability>> availability({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
  }) async {
    try {
      final format = DateFormat('yyyy-MM-dd');
      final rows = await _client.rpc<List<dynamic>>(
        'available_stay_units',
        params: {
          'p_property_id': propertyId,
          'p_check_in': format.format(checkIn),
          'p_check_out': format.format(checkOut),
          'p_adults': adults,
          'p_children': children,
        },
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(StayUnitAvailability.fromJson)
          .toList();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }
}
