import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' as errors;
import '../../booking/domain/booking.dart';
import '../domain/sports_venue.dart';

class SupabaseSportsRepository implements SportsRepository {
  SupabaseSportsRepository(this.client);
  final SupabaseClient client;
  static const select =
      '*,venues!inner(id,name,description,city,state,capacity,is_active,organizations!inner(owner_user_id))';
  @override
  Future<List<SportsVenue>> venues({bool owned = false}) async {
    try {
      var q = client
          .from('sports_venue_profiles')
          .select(select)
          .eq('venues.is_active', true);
      if (owned) {
        final id = client.auth.currentUser?.id;
        if (id == null) return const [];
        q = q.eq('venues.organizations.owner_user_id', id);
      }
      final rows = await q.order('updated_at');
      return rows.map(SportsVenue.fromJson).toList();
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<SportsVenue> venue(String id) async {
    try {
      return SportsVenue.fromJson(
        await client
            .from('sports_venue_profiles')
            .select(select)
            .eq('venue_id', id)
            .single(),
      );
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
