import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' as errors;
import '../../booking/domain/booking.dart';
import '../domain/sports_venue.dart';

class SupabaseSportsRepository implements SportsRepository {
  SupabaseSportsRepository(this.client);
  final SupabaseClient client;

  /// [list_sports_venues] performs the venues join in plain SQL. It returns
  /// the same payload shape as the old PostgREST embedding
  /// ({...profile, venues: {...venue}}) but avoids the two-level `!inner`
  /// embed that older PostgREST versions compiled into an aggregate-in-FROM
  /// query (PostgreSQL 42803).
  @override
  Future<List<SportsVenue>> venues({bool owned = false}) async {
    try {
      final rows = await client.rpc<List<dynamic>>(
        'list_sports_venues',
        params: {'p_owned': owned},
      );
      return rows
          .map((r) => SportsVenue.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<SportsVenue> venue(String id) async {
    try {
      final rows = await client.rpc<List<dynamic>>(
        'list_sports_venues',
        params: {'p_venue_id': id},
      );
      if (rows.isEmpty) {
        throw const errors.NotFoundException('Sports venue not found');
      }
      return SportsVenue.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<SportsQuote> quote(
    String id,
    DateTime date,
    String start,
    int duration,
  ) async {
    try {
      return SportsQuote.fromJson(
        await client.rpc<Map<String, dynamic>>(
          'sports_venue_quote',
          params: {
            'p_venue_id': id,
            'p_book_date': _date(date),
            'p_start_time': start,
            'p_duration_minutes': duration,
          },
        ),
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<List<Booking>> book(
    String id,
    DateTime date,
    String start,
    int duration,
    List<DateTime> recurrence,
  ) async {
    try {
      final ids = await client.rpc<List<dynamic>>(
        'create_sports_booking',
        params: {
          'p_venue_id': id,
          'p_book_date': _date(date),
          'p_start_time': start,
          'p_duration_minutes': duration,
          'p_idempotency_key': _uuid(),
          'p_recurrence_dates': recurrence.map(_date).toList(),
        },
      );
      final rows = await client
          .from('bookings')
          .select('*,venues(id,name,city),time_slots(id,label)')
          .inFilter('id', ids.cast<String>());
      return rows.map(Booking.fromJson).toList();
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<String> create({
    required String name,
    required String city,
    required int capacity,
    required SportType type,
    required double hourlyRate,
    required int sessionMinutes,
    required double sessionRate,
    required int bufferMinutes,
  }) async {
    try {
      return await client.rpc<String>(
        'create_sports_venue',
        params: {
          'p_name': name,
          'p_description': '${type.name} sports facility',
          'p_city': city,
          'p_state': '',
          'p_capacity': capacity,
          'p_sport_type': type.name,
          'p_hourly_rate': hourlyRate,
          'p_session_minutes': sessionMinutes,
          'p_session_rate': sessionRate,
          'p_buffer_minutes': bufferMinutes,
          'p_equipment': <String>['Rackets', 'Balls', 'Nets'],
          'p_amenities': <String>[
            'Parking',
            'Changing room',
            'Lighting',
            'Drinking water',
          ],
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<String> offline(
    String id,
    DateTime date,
    String start,
    int duration,
  ) async {
    try {
      return await client.rpc<String>(
        'create_offline_sports_booking',
        params: {
          'p_venue_id': id,
          'p_book_date': _date(date),
          'p_start_time': start,
          'p_duration_minutes': duration,
          'p_customer_name': 'Walk-in customer',
          'p_customer_phone': '',
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> setMode(String id, String mode) async {
    try {
      await client
          .from('sports_venue_profiles')
          .update({
            'booking_mode': mode,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('venue_id', id);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> addBreak(String id, int day, String start, String end) async {
    try {
      await client.from('sports_venue_breaks').insert({
        'venue_id': id,
        'day_of_week': day,
        'start_time': start,
        'end_time': end,
        'label': 'Maintenance break',
      });
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  static String _date(DateTime d) => d.toIso8601String().split('T').first;
  static String _uuid() {
    final r = Random.secure();
    String h(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${h(3)}-${h(12)}';
  }
}
