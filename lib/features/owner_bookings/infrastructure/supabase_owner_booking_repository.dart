import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../booking/domain/booking.dart';
import '../domain/owner_booking_repository.dart';

/// Supabase-backed [OwnerBookingRepository].
class SupabaseOwnerBookingRepository implements OwnerBookingRepository {
  SupabaseOwnerBookingRepository(this._client);

  final SupabaseClient _client;

  static const String _bookingSelect = '''
    *,
    venues (id, name, city),
    time_slots (id, label),
    payments (method, provider_payment_id, status, created_at)
  ''';

  @override
  Future<List<Booking>> myVenueBookings() async {
    try {
      final venueRows = await _client.rpc<List<dynamic>>('get_owner_venues');
      final ids = venueRows
          .whereType<Map<String, dynamic>>()
          .map((v) => v['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('bookings')
          .select(_bookingSelect)
          .inFilter('venue_id', ids)
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
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'owner-booking-manage',
        body: {
          'action': 'create_offline',
          'venue_id': venueId,
          'slot_id': slotId,
          'book_date': _formatDate(bookDate),
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'amount': amount,
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'idempotency_key': offlineIdempotencyKey(
            venueId: venueId,
            slotId: slotId,
            bookDate: bookDate,
            customerPhone: customerPhone,
          ),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['booking'] is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Owner booking service returned an empty response.',
          code: 'empty_owner_booking_response',
        );
      }
      return Booking.fromJson(
        Map<String, dynamic>.from(data['booking'] as Map),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> updateStatus(
    String bookingId,
    OwnerBookingAction action,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'owner-booking-manage',
        body: {
          'action': 'update_status',
          'booking_id': bookingId,
          'status_action': action.dbValue,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['booking'] is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Owner booking service returned an empty response.',
          code: 'empty_owner_booking_response',
        );
      }
      return Booking.fromJson(
        Map<String, dynamic>.from(data['booking'] as Map),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  app_errors.AppException _mapFunctionException(FunctionException e) {
    final details = e.details;
    final error = details is Map<String, dynamic>
        ? (details['error'] as String? ?? '')
        : '';
    return switch (error) {
      'booking_not_found' || 'venue_not_found' => app_errors.NotFoundException(
        'The booking could not be found.',
        code: error,
        statusCode: e.status,
      ),
      'not_owner' => app_errors.BusinessException(
        'You are not allowed to manage this booking.',
        code: error,
        statusCode: e.status,
      ),
      'slot_unavailable' => const app_errors.BookingConflictException(
        'This slot is no longer available.',
        code: 'slot_unavailable',
      ),
      'invalid_transition' => app_errors.BusinessException(
        'This booking cannot be moved to that status.',
        code: error,
        statusCode: e.status,
      ),
      'confirmed_payment_required' => app_errors.BusinessException(
        'Online bookings must be cancelled through the customer refund flow.',
        code: error,
        statusCode: e.status,
      ),
      'amount_mismatch' => app_errors.BusinessException(
        'The amounts do not match the venue pricing.',
        code: error,
        statusCode: e.status,
      ),
      _ => app_errors.ServerException(
        'Owner booking service error (${e.status}).',
        code: error,
        statusCode: e.status,
      ),
    };
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String offlineIdempotencyKey({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerPhone,
  }) {
    final raw = [
      venueId,
      slotId,
      _formatDate(bookDate),
      customerPhone.trim(),
    ].join('|');
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }
}
