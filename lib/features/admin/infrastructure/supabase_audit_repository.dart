import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/audit_log_entry.dart';
import '../domain/audit_log_repository.dart';

class SupabaseAuditRepository implements AuditLogRepository {
  SupabaseAuditRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AuditLogEntry>> recentLogs({int limit = 100}) async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((r) => AuditLogEntry.fromJson(r)).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}