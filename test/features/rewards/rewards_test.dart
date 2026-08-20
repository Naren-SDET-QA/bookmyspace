import 'package:bookmyspace/features/rewards/domain/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet balance is derived from posted ledger entries', () {
    final summary = WalletSummary.fromEntries([
      WalletEntry(
        direction: 'credit',
        amount: 100,
        description: 'Referral',
        status: 'posted',
        createdAt: DateTime(2026),
      ),
      WalletEntry(
        direction: 'debit',
        amount: 25,
        description: 'Used',
        status: 'posted',
        createdAt: DateTime(2026),
      ),
      WalletEntry(
        direction: 'credit',
        amount: 50,
        description: 'Pending',
        status: 'pending',
        createdAt: DateTime(2026),
      ),
    ]);
    expect(summary.balance, 75);
    expect(summary.earned, 100);
    expect(summary.used, 25);
    expect(summary.pending, 50);
  });

  test('debits reduce balance and pending debits remain pending', () {
    final summary = WalletSummary.fromEntries([
      WalletEntry(
        direction: 'credit',
        amount: 100,
        description: 'Credit',
        status: 'posted',
        createdAt: DateTime(2026),
      ),
      WalletEntry(
        direction: 'debit',
        amount: 10,
        description: 'Pending use',
        status: 'pending',
        createdAt: DateTime(2026),
      ),
    ]);
    expect(summary.balance, 100);
    expect(summary.pending, -10);
  });
}
