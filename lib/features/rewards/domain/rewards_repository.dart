import 'rewards.dart';

abstract class RewardsRepository {
  Future<ReferralSummary> referralSummary();
  Future<void> claimReferral(String code);
  Future<List<WalletEntry>> walletEntries();
}
