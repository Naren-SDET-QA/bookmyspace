import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/pricing_feature.dart';
import '../domain/business_plan.dart';

class SupabaseBusinessConfigRepository {
  SupabaseBusinessConfigRepository(this._client);
  final SupabaseClient _client;

  Future<ContactPaymentOrder> createContactOrder({
    required String venueId,
    required String feature,
  }) async {
    final response = await _client.functions.invoke(
      'create-contact-payment-order',
      body: {'venue_id': venueId, 'feature': feature},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Contact payment service returned an empty response');
    }
    return ContactPaymentOrder.fromJson(data);
  }

  Future<List<PricingFeature>> activePricing() async {
    final rows = await _client
        .from('pricing_features')
        .select('*')
        .eq('is_active', true)
        .order('feature_key')
        .order('version', ascending: false);
    return rows.map(PricingFeature.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> adminPricing() async {
    final rows = await _client
        .from('pricing_features')
        .select('*')
        .order('feature_key')
        .order('version', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createPricing(Map<String, dynamic> values) async {
    await _client.from('pricing_features').insert(values);
  }

  Future<void> disablePricing(String id) async {
    await _client
        .from('pricing_features')
        .update({'is_active': false})
        .eq('id', id);
  }

  Future<List<BusinessPlan>> activePlans() async {
    final rows = await _client
        .from('business_plans')
        .select('*')
        .eq('is_active', true)
        .order('priority_rank')
        .order('amount_minor');
    return rows.map(BusinessPlan.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> adminPlans() async {
    final rows = await _client
        .from('business_plans')
        .select('*')
        .order('priority_rank')
        .order('amount_minor');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createPlan(Map<String, dynamic> values) =>
      _client.from('business_plans').insert(values);

  Future<void> disablePlan(String id) =>
      _client.from('business_plans').update({'is_active': false}).eq('id', id);

  Future<Map<String, dynamic>?> revealContact(
    String venueId,
    String fieldKey,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_contact_with_entitlement',
      params: {'p_venue_id': venueId, 'p_field_key': fieldKey},
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }
}
