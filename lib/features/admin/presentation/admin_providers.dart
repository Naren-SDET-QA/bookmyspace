import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/audit_log_entry.dart';
import '../domain/audit_log_repository.dart';
import '../infrastructure/supabase_audit_repository.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseAuditRepository(client);
});

final recentAuditLogsProvider = FutureProvider<List<AuditLogEntry>>((ref) {
  return ref.watch(auditLogRepositoryProvider).recentLogs(limit: 100);
});
