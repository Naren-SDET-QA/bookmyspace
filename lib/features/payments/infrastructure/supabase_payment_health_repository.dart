import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/payment_health.dart';

class SupabasePaymentHealthRepository implements PaymentHealthRepository {
  SupabasePaymentHealthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentHealthSummary> summary() async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'admin_payment_health_summary',
      );
      return PaymentHealthSummary.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<int> reconcileStale({int staleAfterMinutes = 30}) async {
    try {
      final count = await _client.rpc<int>(
        'admin_reconcile_stale_payments',
        params: {'p_stale_after_minutes': staleAfterMinutes},
      );
      return count;
    } catch (e) {
      throw mapError(e);
    }
  }
}
