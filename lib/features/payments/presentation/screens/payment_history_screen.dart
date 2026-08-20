import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../domain/payment.dart';
import '../payment_providers.dart';

/// Payment history with invoice access for completed Razorpay transactions.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(myPaymentsProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentHistory)),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.payments_outlined,
                title: l10n.noPaymentHistory,
                message: l10n.noPaymentHistoryMessage,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myPaymentsProvider);
                  await ref.read(myPaymentsProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _PaymentHistoryCard(payment: items[index]),
                ),
              ),
      ),
    );
  }
}

class _PaymentHistoryCard extends ConsumerWidget {
  const _PaymentHistoryCard({required this.payment});

  final Payment payment;

  bool get _isCompleted =>
      payment.status == PaymentStatus.captured ||
      payment.status == PaymentStatus.refunded ||
      payment.status == PaymentStatus.partiallyRefunded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingByIdProvider(payment.bookingId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.transactionSummary,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: payment.status),
              ],
            ),
            const Divider(height: 24),
            _HistoryRow(label: l10n.total, value: _formatAmount(payment)),
            if (payment.providerPaymentId.isNotEmpty)
              _HistoryRow(
                label: l10n.razorpayTransactionId,
                value: payment.providerPaymentId,
              ),
            if (payment.providerOrderId.isNotEmpty)
              _HistoryRow(
                label: l10n.razorpayOrderId,
                value: payment.providerOrderId,
              ),
            _HistoryRow(label: l10n.bookingId, value: payment.bookingId),
            if (_isCompleted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/bookings/${payment.bookingId}/invoice'),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.viewInvoice),
                ),
              ),
            ] else if (booking.hasValue && booking.value != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.paymentPending,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAmount(Payment payment) {
    return NumberFormat.currency(
      symbol: payment.currency == 'INR' ? '₹' : '${payment.currency} ',
      decimalDigits: 2,
    ).format(payment.amount);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final successful =
        status == PaymentStatus.captured ||
        status == PaymentStatus.refunded ||
        status == PaymentStatus.partiallyRefunded;
    return Chip(
      label: Text(status.dbValue),
      avatar: Icon(
        successful ? Icons.check_circle_outline : Icons.schedule_outlined,
        size: 16,
      ),
      side: BorderSide.none,
      backgroundColor: successful
          ? Colors.green.withValues(alpha: 0.12)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
