import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/rewards.dart';
import '../domain/rewards_repository.dart';

class SupabaseRewardsRepository implements RewardsRepository {
  SupabaseRewardsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ReferralSummary> referralSummary() async {
    final profile = await _client.rpc('ensure_referral_profile');
    final code = (profile as Map<String, dynamic>)['referral_code'] as String;
    final rows = await _client
        .from('referral_attributions')
        .select('id,status,created_at,rewarded_at,referred_user_id')
        .or(
          'referrer_user_id.eq.${_client.auth.currentUser!.id},referred_user_id.eq.${_client.auth.currentUser!.id}',
        )
        .order('created_at', ascending: false);
    return ReferralSummary(
      code: code,
      items: List<Map<String, dynamic>>.from(rows),
    );
  }

  @override
  Future<void> claimReferral(String code) async {
    await _client.rpc('claim_referral', params: {'p_referral_code': code});
  }

  @override
  Future<List<WalletEntry>> walletEntries() async {
    final rows = await _client
        .from('wallet_ledger')
        .select('direction,amount,description,status,created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(WalletEntry.fromMap).toList();
  }
}
