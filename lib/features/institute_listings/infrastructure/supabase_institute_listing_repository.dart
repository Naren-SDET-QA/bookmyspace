import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/institute_listing.dart';
import '../domain/institute_listing_repository.dart';

class SupabaseInstituteListingRepository implements InstituteListingRepository {
  SupabaseInstituteListingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InstituteListing?> getActiveListingForInstitute(
    String instituteId,
  ) async {
    try {
      final row = await _client
          .from('institute_listings')
          .select()
          .eq('institute_id', instituteId)
          .eq('is_active', true)
          .order('ends_at', ascending: false)
          .maybeSingle();
      if (row == null) return null;
      return InstituteListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<InstituteListing> createListing({
    required String instituteId,
    required String planId,
  }) async {
    try {
      final plan = await _client
          .from('institute_listing_plans')
          .select('duration_in_days')
          .eq('id', planId)
          .maybeSingle();
      final days = (plan?['duration_in_days'] as num?)?.toInt() ?? 30;
      final now = DateTime.now().toUtc();
      final row = await _client
          .from('institute_listings')
          .insert({
            'institute_id': instituteId,
            'plan_id': planId,
            'starts_at': now.toIso8601String(),
            'ends_at': now.add(Duration(days: days)).toIso8601String(),
            'is_active': false,
          })
          .select()
          .single();
      return InstituteListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> updateListing(
    String id, {
    String? paymentId,
    bool? isActive,
  }) async {
    try {
      final patch = <String, dynamic>{};
      if (paymentId != null) patch['payment_id'] = paymentId;
      if (isActive != null) patch['is_active'] = isActive;
      if (patch.isEmpty) return;
      await _client.from('institute_listings').update(patch).eq('id', id);
    } catch (e) {
      throw mapError(e);
    }
  }
}
