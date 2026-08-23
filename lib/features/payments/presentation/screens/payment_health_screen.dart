import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/payment_health.dart';
import '../../infrastructure/supabase_payment_health_repository.dart';

final paymentHealthRepositoryProvider = Provider<PaymentHealthRepository>((ref) {
  return SupabasePaymentHealthRepository(ref.watch(supabaseProvider));
});

final paymentHealthSummaryProvider = FutureProvider<PaymentHealthSummary>((ref) {
  return ref.watch(paymentHealthRepositoryProvider).summary();
});

/// Admin view of live payment health.
///
/// Uses Supabase payment/refund/hold rows and the existing
/// `reconcile_stale_payments` job. Does not store transactions in a local
/// database and does not treat client checkout as confirmation.
class PaymentHealthScreen extends ConsumerStatefulWidget {
  const PaymentHealthScreen({super.key});

  @override
  ConsumerState<PaymentHealthScreen> createState() =>
      _PaymentHealthScreenState();
}

class _PaymentHealthScreenState extends ConsumerState<PaymentHealthScreen> {
  bool _reconciling = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(paymentHealthSummaryProvider);
    final sandbox = AppConfig.razorpayKeyId.contains('test') ||
        AppConfig.razorpayKeyId.contains('PLACEHOLDER');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & self-healing'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(sandbox ? 'RAZORPAY TEST' : 'RAZORPAY'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(paymentHealthSummaryProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Gateway orders are created on the server. Webhooks confirm capture. '
              'This screen never marks a payment successful from the client.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatCard('Pending', data.pending, Colors.orange),
                _StatCard('Captured', data.captured, Colors.green),
                _StatCard('Failed', data.failed, Colors.red),
                _StatCard('Refunded', data.refunded, AppTheme.brand),
                _StatCard('Active holds', data.activeHolds, Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Refunds by status',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (data.refundsByStatus.isEmpty)
              const Text('No refund rows visible.')
            else
              ...data.refundsByStatus.entries.map(
                (e) => ListTile(
                  dense: true,
                  title: Text(e.key),
                  trailing: Text('${e.value}'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reconciling ? null : _reconcile,
              icon: _reconciling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.healing),
              label: Text(
                _reconciling
                    ? 'Reconciling…'
                    : 'Reconcile stale pending payments',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only pending payments older than 30 minutes are marked failed. '
              'Captured payments and confirmed bookings are not rewritten.',
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reconcile() async {
    setState(() {
      _reconciling = true;
      _message = null;
    });
    try {
      final count = await ref
          .read(paymentHealthRepositoryProvider)
          .reconcileStale();
      setState(() => _message = 'Marked $count stale pending payment(s) failed.');
      ref.invalidate(paymentHealthSummaryProvider);
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _reconciling = false);
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
