import 'package:flutter/material.dart';

import '../../domain/booking_preview.dart';

class BookingPreviewCard extends StatelessWidget {
  const BookingPreviewCard({
    super.key,
    required this.preview,
    required this.submitting,
    required this.onConfirm,
    required this.onChange,
  });
  final BookingPreview preview;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(preview.venueName),
          Text('${preview.date} · ${preview.slotLabel}'),
          Text('Quantity: ${preview.quantity}'),
          const Divider(),
          Text(
            'Base price: ${preview.currency} ${preview.baseAmount.toStringAsFixed(2)}',
          ),
          Text(
            'Tax/fees: ${preview.currency} ${(preview.taxAmount + preview.feeAmount).toStringAsFixed(2)}',
          ),
          if (preview.discountAmount > 0)
            Text(
              'Offer/discount: -${preview.currency} ${preview.discountAmount.toStringAsFixed(2)}',
            ),
          Text(
            'Total: ${preview.currency} ${preview.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : onChange,
                  child: const Text('CHANGE'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: submitting ? null : onConfirm,
                  child: Text(submitting ? 'Working…' : 'CONFIRM BOOKING'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
