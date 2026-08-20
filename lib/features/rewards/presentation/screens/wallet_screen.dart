import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/rewards.dart';
import '../rewards_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(walletEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load wallet: $e')),
        data: (items) {
          final summary = WalletSummary.fromEntries(items);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(walletEntriesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available balance'),
                        const SizedBox(height: 8),
                        Text(
                          '₹${summary.balance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Earned ₹${summary.earned.toStringAsFixed(2)}  ·  Used ₹${summary.used.toStringAsFixed(2)}  ·  Pending ₹${summary.pending.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transaction history',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...items.map(
                  (e) => ListTile(
                    leading: Icon(
                      e.direction == 'credit'
                          ? Icons.add_circle
                          : Icons.remove_circle,
                      color: e.direction == 'credit'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(e.description),
                    subtitle: Text(e.status),
                    trailing: Text(
                      '${e.direction == 'credit' ? '+' : '-'}₹${e.amount.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
