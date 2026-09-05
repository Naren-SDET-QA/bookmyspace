import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/observability.dart';

class HelpArticleAdminRepository {
  HelpArticleAdminRepository(this.client);
  final SupabaseClient client;

  Future<void> save({String? id, required String category, required String language, required String title, required String summary, required String steps, required int sortOrder, required bool enabled}) async {
    final row = {'category': category, 'language': language, 'title': title, 'summary': summary, 'steps': steps, 'sort_order': sortOrder, 'enabled': enabled, 'archived_at': null, 'updated_at': DateTime.now().toIso8601String()};
    if (id == null) {
      await client.from('help_articles').insert(row);
    } else {
      await client.from('help_articles').update(row).eq('id', id);
    }
  }

  Future<void> archive(String id) => client.from('help_articles').update({'archived_at': DateTime.now().toIso8601String(), 'enabled': false}).eq('id', id);
  Future<void> setEnabled(String id, bool enabled) => client.from('help_articles').update({'enabled': enabled}).eq('id', id);
}

final healthSnapshotsProvider = FutureProvider<List<HealthSnapshot>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('health_checks').select('feature,status,response_ms').order('checked_at', ascending: false).limit(100);
  final seen = <String>{};
  return (rows as List).map((row) => HealthSnapshot.fromMap(Map<String, dynamic>.from(row as Map))).where((item) => seen.add(item.feature)).toList();
});

final helpArticlesProvider = FutureProvider<List<HelpArticle>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('help_articles').select('id,category,title,summary,steps,language,enabled').eq('enabled', true).isFilter('archived_at', null).order('sort_order').limit(100);
  return (rows as List).map((row) => HelpArticle.fromMap(Map<String, dynamic>.from(row as Map))).toList();
});

final errorEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('error_events').select('id,feature,category,severity,status,retry_count,last_error,created_at').order('created_at', ascending: false).limit(100);
  return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
});

final recoveryEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('recovery_events').select('id,feature,action,status,created_at').order('created_at', ascending: false).limit(100);
  return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
});

final alertRulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('alert_rules').select('id,feature,condition,operator,threshold,duration_seconds,enabled').order('created_at', ascending: false).limit(100);
  return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
});
