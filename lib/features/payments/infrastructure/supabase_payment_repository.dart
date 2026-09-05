import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../booking/domain/booking.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';

/// Supabase-backed [PaymentRepository].
///
/// Order creation and refunds go through Edge Functions so Razorpay secrets
/// never reach the client. Booking confirmation is applied by the
/// `razorpay-webhook` (payment.captured), which this repository only observes
/// through [bookingStatus].
class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentOrder> createOrder({required String bookingId}) async {
    try {
      final response = await _client.functions.invoke(
        'create-payment-order',
        body: {'booking_id': bookingId},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Payment service returned an empty response.',
          code: 'empty_payment_response',
        );
      }
      return PaymentOrder.fromResponse(data);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<BookingStatus> selectPayAtVenue({required String bookingId}) async {
    try {
      final data = await _client.rpc<Object?>(
        'select_pay_at_venue',
        params: {'p_booking_id': bookingId},
      );
      final status = data is Map<String, dynamic>
          ? data['status'] as String? ?? 'pending_owner_approval'
          : 'pending_owner_approval';
      return BookingStatus.fromDb(status);
    } on PostgrestException catch (e) {
      throw _mapPayAtVenueError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  /// Maps the stable error strings raised by `select_pay_at_venue` (see
  /// the Phase 18 migration) to typed exceptions. The RPC never trusts a
  /// client-supplied amount — it always re-reads `bookings.total_amount`.
  app_errors.AppException _mapPayAtVenueError(PostgrestException e) {
    return switch (e.message) {
      'unauthorized' => const app_errors.AuthException(
        'You must be signed in to choose a payment method.',
        code: 'unauthorized',
      ),
      'booking_not_found' => const app_errors.NotFoundException(
        'Booking not found.',
        code: 'booking_not_found',
      ),
      'not_booking_owner' => const app_errors.BusinessException(
        'This booking does not belong to you.',
        code: 'not_booking_owner',
      ),
      'invalid_booking_state' => const app_errors.BusinessException(
        'This booking can no longer choose a payment method.',
        code: 'invalid_booking_state',
      ),
      'payment_in_progress' => const app_errors.BusinessException(
        'A payment for this booking is already in progress.',
        code: 'payment_in_progress',
      ),
      _ => app_errors.ServerException(
        'Could not select pay at venue.',
        code: e.message,
      ),
    };
  }

  @override
  Future<BookingStatus> bookingStatus(String bookingId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException(
          'You must be signed in to check a booking.',
        );
      }
      final row = await _client
          .from('bookings')
          .select('status')
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .maybeSingle();
      return BookingStatus.fromDb(row?['status'] as String? ?? 'pending');
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Refund> requestRefund({
    required String bookingId,
    required double amount,
    String reason = '',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-refund',
        body: {
          'booking_id': bookingId,
          'amount': amount,
          if (reason.isNotEmpty) 'reason': reason,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Refund service returned an empty response.',
          code: 'empty_refund_response',
        );
      }
      return Refund.fromResponse(data);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Payment>> myPayments() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final rows = await _client
          .from('payments')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Payment.fromJson)
          .toList();
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
      'booking_not_found' => app_errors.NotFoundException(
        'The booking could not be found.',
        code: error,
        statusCode: e.status,
      ),
      'not_authorized' => app_errors.BusinessException(
        'You are not allowed to pay for this booking.',
        code: error,
        statusCode: e.status,
      ),
      'amount_mismatch' => app_errors.BusinessException(
        'The payment amount does not match the booking total.',
        code: error,
        statusCode: e.status,
      ),
      'payment_duplicate' => app_errors.BusinessException(
        'A payment for this booking already exists.',
        code: error,
        statusCode: e.status,
      ),
      'not_refundable' => app_errors.BusinessException(
        'This booking is not refundable.',
        code: error,
        statusCode: e.status,
      ),
      'no_captured_payment' => app_errors.BusinessException(
        'No captured payment was found for this booking.',
        code: error,
        statusCode: e.status,
      ),
      'invalid_amount' => app_errors.BusinessException(
        'The refund amount is invalid.',
        code: error,
        statusCode: e.status,
      ),
      'already_refunded' => app_errors.BusinessException(
        'This booking has already been refunded.',
        code: error,
        statusCode: e.status,
      ),
      'hold_expired' => app_errors.HoldExpiredException(
        'This hold has expired. Pick the slot again.',
        code: error,
      ),
      _ => app_errors.ServerException(
        'Payment service error (${e.status}).',
        code: error,
        statusCode: e.status,
      ),
    };
  }
}
