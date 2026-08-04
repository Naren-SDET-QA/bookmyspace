import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/payment.dart';
import '../payment_providers.dart';
import '../receipt_download.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(paymentReceiptProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: receipt.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(paymentReceiptProvider(bookingId)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            _ReceiptCard(receipt: data),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _download(context, data),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download receipt'),
            ),
            OutlinedButton.icon(
              onPressed: () => _share(context, data),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, PaymentReceipt receipt) async {
    final text = _receiptText(receipt);
    final downloaded = await downloadReceipt(
      '${receipt.receiptNumber.isEmpty ? receipt.bookingRef : receipt.receiptNumber}.txt',
      text,
    );
    if (!downloaded) await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Receipt downloaded'
                : 'Receipt copied. Paste it into a file to save.',
          ),
        ),
      );
    }
  }

  Future<void> _share(BuildContext context, PaymentReceipt receipt) async {
    await Clipboard.setData(ClipboardData(text: _receiptText(receipt)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt copied for sharing')),
      );
    }
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});
  final PaymentReceipt receipt;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: AppTheme.success, size: 52),
          const SizedBox(height: 8),
          Text(
            'BOOKMYSPACE',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            receipt.receiptNumber.isEmpty
                ? receipt.bookingRef
                : receipt.receiptNumber,
          ),
          const Divider(height: 28),
          _Line('Booking ID', receipt.bookingRef),
          _Line('Hall', receipt.hallName),
          _Line('Customer', receipt.customerName),
          if (receipt.customerPhone.isNotEmpty)
            _Line('Phone', receipt.customerPhone),
          _Line('Date', DateFormat.yMMMd().format(receipt.bookDate)),
          _Line(
            'Time',
            '${_time(receipt.startTime)}–${_time(receipt.endTime)}',
          ),
          const Divider(height: 24),
          _Line('Base amount', formatInr(receipt.amount)),
          _Line('Tax', formatInr(receipt.taxAmount)),
          _Line('Total', formatInr(receipt.totalAmount), strong: true),
          const Divider(height: 24),
          _Line('Payment', receipt.paymentStatus.toUpperCase()),
          _Line('Booking', receipt.bookingStatus.toUpperCase()),
          if (receipt.paymentRef.isNotEmpty)
            _Line('Payment ref', receipt.paymentRef),
        ],
      ),
    ),
  );

  static String _time(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

String _receiptText(PaymentReceipt r) =>
    '''
BookMySpace Receipt
Receipt: ${r.receiptNumber.isEmpty ? r.bookingRef : r.receiptNumber}
Booking ID: ${r.bookingRef}
Hall: ${r.hallName}
Customer: ${r.customerName}${r.customerPhone.isEmpty ? '' : ' (${r.customerPhone})'}
Date: ${DateFormat.yMMMd().format(r.bookDate)}
Time: ${r.startTime} - ${r.endTime}
Base: ${formatInr(r.amount)}
Tax: ${formatInr(r.taxAmount)}
Total: ${formatInr(r.totalAmount)}
Payment status: ${r.paymentStatus}
Booking status: ${r.bookingStatus}
Payment reference: ${r.paymentRef}
''';
