import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../booking/domain/booking.dart';
import '../domain/meeting_room.dart';

class SupabaseMeetingRoomRepository implements MeetingRoomRepository {
  SupabaseMeetingRoomRepository(this.client);
  final SupabaseClient client;

  /// [list_meeting_rooms] performs the venues join in plain SQL. It returns
  /// the same payload shape as the old PostgREST embedding
  /// ({...profile, venues: {...venue}}) but avoids the two-level `!inner`
  /// embed that older PostgREST versions compiled into an aggregate-in-FROM
  /// query (PostgreSQL 42803).
  List<MeetingRoom> _mapRows(List<dynamic> rows) => rows
      .map((r) => MeetingRoom.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();

  @override
  Future<List<MeetingRoom>> rooms() async {
    try {
      final rows = await client.rpc<List<dynamic>>('list_meeting_rooms');
      return _mapRows(rows);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<MeetingRoom>> ownedRooms() async {
    try {
      if (client.auth.currentUser?.id == null) return const [];
      final rows = await client.rpc<List<dynamic>>(
        'list_meeting_rooms',
        params: {'p_owned': true},
      );
      return _mapRows(rows);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<MeetingRoom> room(String id) async {
    try {
      final rows = await client.rpc<List<dynamic>>(
        'list_meeting_rooms',
        params: {'p_venue_id': id},
      );
      if (rows.isEmpty) {
        throw const app_errors.NotFoundException('Meeting room not found');
      }
      return _mapRows(rows).first;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<MeetingRoomQuote> quote(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
  ) async {
    try {
      final data = await client.rpc<Map<String, dynamic>>(
        'meeting_room_quote',
        params: {
          'p_venue_id': roomId,
          'p_book_date': _date(date),
          'p_start_time': startTime,
          'p_duration_minutes': durationMinutes,
        },
      );
      return MeetingRoomQuote.fromJson(data);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Booking>> book(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
    List<DateTime> recurrenceDates,
  ) async {
    try {
      final ids = await client.rpc<List<dynamic>>(
        'create_meeting_booking',
        params: {
          'p_venue_id': roomId,
          'p_book_date': _date(date),
          'p_start_time': startTime,
          'p_duration_minutes': durationMinutes,
          'p_idempotency_key': _uuid(),
          'p_recurrence_dates': recurrenceDates.map(_date).toList(),
        },
      );
      final rows = await client
          .from('bookings')
          .select('*,venues(id,name,city),time_slots(id,label)')
          .inFilter('id', ids.cast<String>());
      return rows.map(Booking.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<String> createRoom({
    required String name,
    required String description,
    required String city,
    required String state,
    required int capacity,
    required MeetingRoomType type,
    required double hourlyRate,
    required double halfDayRate,
    required double fullDayRate,
    required int bufferMinutes,
    required List<String> amenities,
  }) async {
    try {
      return await client.rpc<String>(
        'create_meeting_room',
        params: {
          'p_name': name,
          'p_description': description,
          'p_city': city,
          'p_state': state,
          'p_latitude': 17.385,
          'p_longitude': 78.4867,
          'p_capacity': capacity,
          'p_room_type': type.name,
          'p_hourly_rate': hourlyRate,
          'p_half_day_rate': halfDayRate,
          'p_full_day_rate': fullDayRate,
          'p_buffer_minutes': bufferMinutes,
          'p_amenities': amenities,
        },
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<String> offlineBooking(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
    String customerName,
    String customerPhone,
  ) async {
    try {
      return await client.rpc<String>(
        'create_offline_meeting_booking',
        params: {
          'p_venue_id': roomId,
          'p_book_date': _date(date),
          'p_start_time': startTime,
          'p_duration_minutes': durationMinutes,
          'p_customer_name': customerName,
          'p_customer_phone': customerPhone,
        },
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> addBreak(
    String roomId,
    int dayOfWeek,
    String startTime,
    String endTime,
    String label,
  ) async {
    try {
      await client.from('meeting_room_breaks').insert({
        'venue_id': roomId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'label': label,
      });
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> setWorkingHours(
    String roomId,
    int dayOfWeek,
    String opensAt,
    String closesAt, {
    bool closed = false,
  }) async {
    try {
      await client.from('venue_operating_hours').upsert({
        'venue_id': roomId,
        'day_of_week': dayOfWeek,
        'opens_at': opensAt,
        'closes_at': closesAt,
        'is_closed': closed,
      }, onConflict: 'venue_id,day_of_week');
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> setBookingMode(String roomId, String mode) async {
    try {
      await client
          .from('meeting_room_profiles')
          .update({
            'booking_mode': mode,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('venue_id', roomId);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  static String _date(DateTime value) =>
      value.toIso8601String().split('T').first;
  static String _uuid() {
    final r = Random.secure();
    String h(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${h(3)}-${h(12)}';
  }
}
