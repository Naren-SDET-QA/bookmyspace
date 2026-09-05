import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/owner_availability.dart';
import '../domain/owner_availability_repository.dart';

class SupabaseOwnerAvailabilityRepository
    implements OwnerAvailabilityRepository {
  SupabaseOwnerAvailabilityRepository(this.client);
  final SupabaseClient client;

  Future<void> _requireOwnerVenue(String venueId) async {
    final rows = await client.rpc<List<dynamic>>('get_owner_venues');
    if (!rows.whereType<Map<String, dynamic>>().any(
      (r) => r['id'] == venueId,
    )) {
      throw StateError('This venue is not owned by the current account.');
    }
  }

  @override
  Future<List<OwnerOperatingHours>> hours(String venueId) async {
    try {
      await _requireOwnerVenue(venueId);
      final rows = await client
          .from('venue_operating_hours')
          .select()
          .eq('venue_id', venueId)
          .order('day_of_week');
      return rows.map(OwnerOperatingHours.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> saveHours(
    String venueId,
    List<OwnerOperatingHours> values,
  ) async {
    try {
      await _requireOwnerVenue(venueId);
      await client
          .from('venue_operating_hours')
          .upsert(
            values.map((v) => v.toJson(venueId)).toList(),
            onConflict: 'venue_id,day_of_week',
          );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OwnerTimeSlot>> slots(String venueId) async {
    try {
      await _requireOwnerVenue(venueId);
      final rows = await client
          .from('time_slots')
          .select()
          .eq('venue_id', venueId)
          .order('start_time');
      return rows.map(OwnerTimeSlot.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<OwnerTimeSlot> saveSlot(String venueId, OwnerTimeSlot slot) async {
    try {
      await _requireOwnerVenue(venueId);
      final payload = <String, dynamic>{
        if (slot.id != null) 'id': slot.id,
        'venue_id': venueId,
        'label': slot.label,
        'start_time': slot.startTime,
        'end_time': slot.endTime,
        'price_amount': slot.priceAmount,
        'is_active': slot.isActive,
      };
      final row = await client
          .from('time_slots')
          .upsert(payload)
          .select()
          .single();
      return OwnerTimeSlot.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> setSlotActive(String venueId, String slotId, bool active) async {
    try {
      await _requireOwnerVenue(venueId);
      await client
          .from('time_slots')
          .update({'is_active': active})
          .eq('id', slotId)
          .eq('venue_id', venueId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteSlot(String venueId, String slotId) async {
    try {
      await _requireOwnerVenue(venueId);
      await client
          .from('time_slots')
          .update({'is_active': false})
          .eq('id', slotId)
          .eq('venue_id', venueId);
    } catch (e) {
      throw mapError(e);
    }
  }
}
