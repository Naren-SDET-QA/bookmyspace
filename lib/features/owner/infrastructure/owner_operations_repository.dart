import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/owner_dashboard_stats.dart';

class OwnerOperationsRepository {
  OwnerOperationsRepository(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> bookings() async =>
      (await client.rpc<List<dynamic>>(
        'owner_booking_requests',
      )).whereType<Map<String, dynamic>>().toList();
  Future<List<Map<String, dynamic>>> payments() => client
      .from('payments')
      .select('*,bookings!inner(booking_ref,venue_id,venues(name))')
      .order('created_at', ascending: false);

  /// Live dashboard metrics derived from owner bookings and payments.
  Future<OwnerDashboardStats> dashboardStats() async {
    final bookings = await this.bookings();
    final payments = await this.payments();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);

    var monthlyRevenue = 0.0;
    for (final payment in payments) {
      final status = payment['status'] as String? ?? '';
      final createdAt = DateTime.tryParse(payment['created_at'] as String? ?? '');
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      if (status == 'captured' &&
          createdAt != null &&
          !createdAt.isBefore(monthStart)) {
        monthlyRevenue += amount;
      }
    }

    var pendingApprovals = 0;
    var todayBookings = 0;
    for (final booking in bookings) {
      final status = booking['workflow_status'] as String? ?? '';
      if (status == 'requested') pendingApprovals++;
      final bookDate = DateTime.tryParse(booking['book_date'] as String? ?? '');
      if (bookDate != null &&
          bookDate.year == today.year &&
          bookDate.month == today.month &&
          bookDate.day == today.day) {
        todayBookings++;
      }
    }

    return OwnerDashboardStats(
      monthlyRevenue: monthlyRevenue,
      totalBookings: bookings.length,
      pendingApprovals: pendingApprovals,
      todayBookings: todayBookings,
    );
  }

  Future<List<Map<String, dynamic>>> slots(String venueId) => client
      .from('time_slots')
      .select()
      .eq('venue_id', venueId)
      .order('start_time');
  Future<List<Map<String, dynamic>>> daySlots(
    String venueId,
    DateTime date,
  ) async => (await client.rpc<List<dynamic>>(
    'owner_day_slots',
    params: {'p_venue_id': venueId, 'p_book_date': _date(date)},
  )).whereType<Map<String, dynamic>>().toList();
  Future<void> decide(String id, bool accept, {String? reason}) =>
      client.rpc<void>(
        'owner_decide_booking',
        params: {'p_booking_id': id, 'p_accept': accept, 'p_reason': reason},
      );
  Future<void> addSlot(
    String venueId,
    String label,
    String start,
    String end,
    double price,
  ) => client.from('time_slots').insert({
    'venue_id': venueId,
    'label': label,
    'start_time': start,
    'end_time': end,
    'price_amount': price,
  });
  Future<void> updateSlot({
    required String slotId,
    required String label,
    required String start,
    required String end,
    required double price,
  }) => client
      .from('time_slots')
      .update({
        'label': label,
        'start_time': start,
        'end_time': end,
        'price_amount': price,
      })
      .eq('id', slotId);
  Future<void> deleteSlot(String slotId) =>
      client.from('time_slots').delete().eq('id', slotId);
  Future<void> toggleSlot(String slotId, bool active) =>
      client.from('time_slots').update({'is_active': active}).eq('id', slotId);
  Future<void> blockDate(String venueId, DateTime date, String reason) =>
      client.from('venue_blocked_dates').upsert({
        'venue_id': venueId,
        'blocked_date': date.toIso8601String().split('T').first,
        'reason': reason,
      });
  Future<void> setDateBlocked(String venueId, DateTime date, bool blocked) =>
      client.rpc<void>(
        'owner_set_date_block',
        params: {
          'p_venue_id': venueId,
          'p_date': _date(date),
          'p_blocked': blocked,
        },
      );
  Future<void> setSlotBlocked(
    String venueId,
    String slotId,
    DateTime date,
    bool blocked,
  ) => client.rpc<void>(
    'owner_set_slot_block',
    params: {
      'p_venue_id': venueId,
      'p_slot_id': slotId,
      'p_date': _date(date),
      'p_blocked': blocked,
    },
  );
  Future<void> copyDay(
    String venueId,
    DateTime source,
    List<DateTime> targets,
  ) => client.rpc<void>(
    'owner_copy_day_availability',
    params: {
      'p_venue_id': venueId,
      'p_source': _date(source),
      'p_targets': targets.map(_date).toList(),
    },
  );
  Future<Map<String, dynamic>> hallSettings(String venueId) async =>
      await client
          .from('hall_booking_settings')
          .select()
          .eq('venue_id', venueId)
          .maybeSingle() ??
      {
        'venue_id': venueId,
        'booking_mode': 'instant',
        'min_notice_minutes': 0,
        'max_advance_days': 365,
        'instant_book_window_hours': 48,
        'approval_timeout_minutes': 1440,
        'checkout_hold_minutes': 10,
      };
  Future<void> saveHallSettings(Map<String, dynamic> settings) => client
      .from('hall_booking_settings')
      .upsert({...settings, 'updated_at': DateTime.now().toIso8601String()});
  Future<String> offline({
    required String venueId,
    required String slotId,
    required DateTime date,
    required String name,
    required String phone,
  }) => client.rpc<String>(
    'create_offline_booking',
    params: {
      'p_venue_id': venueId,
      'p_slot_id': slotId,
      'p_book_date': date.toIso8601String().split('T').first,
      'p_customer_name': name,
      'p_customer_phone': phone,
    },
  );

  static String _date(DateTime value) =>
      value.toIso8601String().split('T').first;
}
