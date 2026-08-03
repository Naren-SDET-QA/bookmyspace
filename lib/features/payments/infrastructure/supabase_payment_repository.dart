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
      _ => app_errors.ServerException(
        'Payment service error (${e.status}).',
        code: error,
        statusCode: e.status,
      ),
    };
  }
}
