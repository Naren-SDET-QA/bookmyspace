import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/check_in.dart';

class SupabaseCheckInRepository implements CheckInRepository {
  SupabaseCheckInRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CheckInResult> checkIn({
    required String code,
    String method = 'code',
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'check_in_booking',
        params: {
          'p_code': code.trim(),
          'p_method': method,
        },
      );
      return CheckInResult.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }
}
