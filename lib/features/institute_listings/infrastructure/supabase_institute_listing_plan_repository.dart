import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/institute_listing_plan.dart';
import '../domain/institute_listing_plan_repository.dart';

class SupabaseInstituteListingPlanRepository
    implements InstituteListingPlanRepository {
  SupabaseInstituteListingPlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<InstituteListingPlan>> getActivePlans() async {
    try {
      final rows = await _client
          .from('institute_listing_plans')
          .select()
          .eq('is_active', true);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(InstituteListingPlan.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }
}
