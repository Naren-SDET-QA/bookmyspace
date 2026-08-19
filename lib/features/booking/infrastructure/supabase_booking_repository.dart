import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/booking.dart';
import '../domain/booking_repository.dart';

/// Supabase-backed [BookingRepository].
///
/// * Availability is read through the `available_time_slots` RPC (a
///   security-definer function that computes availability across all users).
/// * The atomic slot lock is acquired via the `create-booking-hold` Edge
///   Function — the server validates the amount and prevents double-booking
///   with an advisory lock, so the client never needs elevated privileges.
/// * Bookings are inserted by the user (RLS allows `auth.uid() = user_id`)
///   and confirmed later by the Razorpay webhook (Milestone 5).
class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  static const String _slotSelect = '''
    *,
    venues (id, name, city),
    time_slots (id, label),
    payments (method, provider_payment_id, status, created_at)
  ''';

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async {
    try {
      final data = await _client.rpc<List<dynamic>>(
        'available_time_slots',
        params: {'p_venue_id': venueId, 'p_book_date': _formatDate(date)},
      );
      return data
          .whereType<Map<String, dynamic>>()
          .map(SlotAvailability.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-booking-hold',
        body: {
          'venue_id': venueId,
          'slot_id': slotId,
          'book_date': _formatDate(bookDate),
          'idempotency_key': _newUuid(),
          'amount': amount,
          'hold_minutes': holdMinutes,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const app_errors.AppError('Empty response from booking service.');
      }
      return BookingHold.fromResponse(data);
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map<String, dynamic>
          ? (details['error'] as String? ?? '')
          : '';
      if (error == 'slot_unavailable') {
        throw const app_errors.BookingConflictException(
          'This slot was just taken. Please pick another.',
          code: 'slot_unavailable',
        );
      }
      throw app_errors.ServerException(
        'Booking service error (${e.status}).',
        code: error,
        statusCode: e.status,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException('You must be signed in to book.');
      }
      // Fetch slot times so the booking rows carry authoritative start/end.
      final slot = await _client
          .from('time_slots')
          .select('label, start_time, end_time')
          .eq('id', slotId)
          .maybeSingle();
      final start = slot?['start_time'] as String? ?? '';
      final end = slot?['end_time'] as String? ?? '';

      final row = await _client
          .from('bookings')
          .insert({
            'booking_ref': _bookingRef(),
            'user_id': user.id,
            'venue_id': venueId,
            'slot_id': slotId,
            'book_date': _formatDate(bookDate),
            'start_time': start,
            'end_time': end,
            'hold_id': hold.id,
            'status': 'pending',
            'quantity': 1,
            'amount': amount,
            'tax_amount': taxAmount,
            'total_amount': totalAmount,
            'currency': 'INR',
            if (metadata.isNotEmpty) 'metadata': metadata,
          })
          .select(_slotSelect)
          .single();
      return Booking.fromJson(row);
    } on PostgrestException catch (e) {
      // 23P01 = exclusion_violation (the bookings_no_overlap constraint).
      if (e.code == '23P01') {
        throw const app_errors.BookingConflictException(
          'This slot is no longer available.',
          code: 'slot_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> bookingById(String bookingId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException('You must be signed in to book.');
      }
      final row = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('id', bookingId)
          .maybeSingle();
      if (row == null) {
        throw const app_errors.NotFoundException('Booking not found.');
      }
      return Booking.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Booking>> myBookings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final rows = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('user_id', user.id)
          .order('book_date', ascending: false)
          .order('start_time', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException(
          'You must be signed in to cancel.',
        );
      }
      final List<Map<String, dynamic>> result = await _client
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .select('id');
      if (result.isEmpty) {
        // The booking may already be confirmed — cancelling is not allowed.
        throw const app_errors.BookingConflictException(
          'This booking can no longer be cancelled.',
          code: 'cannot_cancel',
        );
      }
      // Keep the existing cancellation contract, while recording a durable
      // notification for the signed-in customer.
      try {
        await _client.from('notifications').insert({
          'user_id': user.id,
          'title': 'Booking cancelled',
          'body': 'Your pending booking has been cancelled.',
          'type': 'booking_cancelled',
          'data': {'booking_id': bookingId},
        });
      } catch (_) {
        // Notification delivery is best-effort; cancellation already won.
      }
    } catch (e) {
      if (e is app_errors.BookingConflictException) rethrow;
      throw app_errors.mapError(e);
    }
  }

  /// Formats a date as the local `YYYY-MM-DD` the DB expects.
  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Collision-resistant booking reference, e.g. `BMS-26AB39`.
  static String _bookingRef() {
    final n = Random().nextInt(0xFFFFFF);
    return 'BMS-${n.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  /// A random UUID v4 string (idempotency keys must be unique per attempt).
  static String _newUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }
}
