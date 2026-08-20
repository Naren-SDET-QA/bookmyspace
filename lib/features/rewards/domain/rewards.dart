class WalletEntry {
  const WalletEntry({
    required this.direction,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
  });
  final String direction;
  final double amount;
  final String description;
  final String status;
  final DateTime createdAt;
  factory WalletEntry.fromMap(Map<String, dynamic> json) => WalletEntry(
    direction: json['direction'] as String? ?? 'credit',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    description: json['description'] as String? ?? '',
    status: json['status'] as String? ?? 'posted',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.earned,
    required this.used,
    required this.pending,
  });
  final double balance;
  final double earned;
  final double used;
  final double pending;

  factory WalletSummary.fromEntries(Iterable<WalletEntry> entries) {
    double earned = 0, used = 0, pending = 0;
    for (final entry in entries) {
      if (entry.status == 'pending') {
        pending += entry.direction == 'credit' ? entry.amount : -entry.amount;
        continue;
      }
      if (entry.status != 'posted') continue;
      if (entry.direction == 'credit')
        earned += entry.amount;
      else
        used += entry.amount;
    }
    return WalletSummary(
      balance: earned - used,
      earned: earned,
      used: used,
      pending: pending,
    );
  }
}

class ReferralSummary {
  const ReferralSummary({required this.code, required this.items});
  final String code;
  final List<Map<String, dynamic>> items;
}
