import '../domain/audit_log_entry.dart';

abstract interface class AuditLogRepository {
  Future<List<AuditLogEntry>> recentLogs({int limit});
}