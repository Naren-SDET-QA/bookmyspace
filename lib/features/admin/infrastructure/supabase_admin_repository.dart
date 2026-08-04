import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminRepository {
  const SupabaseAdminRepository(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> rows(List<String> tables) async {
    final rows = <Map<String, dynamic>>[];
    for (final table in tables) {
      final result = await client.from(table).select().limit(100);
      rows.addAll(
        List<Map<String, dynamic>>.from(
          result,
        ).map((row) => {...row, '_source': table}),
      );
    }
    return rows;
  }
}
