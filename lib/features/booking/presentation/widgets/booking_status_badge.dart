import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/booking.dart';

/// Colored pill showing a booking's lifecycle status.
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      BookingStatus.held => (l10n.statusHeld, Colors.orange),
      BookingStatus.pending => (l10n.statusPending, Colors.orange),
      BookingStatus.confirmed => (l10n.statusConfirmed, Colors.green),
      BookingStatus.completed => (l10n.statusCompleted, Colors.blue),
      BookingStatus.cancelled => (l10n.statusCancelled, Colors.grey),
      BookingStatus.refunded => (l10n.statusRefunded, Colors.teal),
      BookingStatus.noShow => (l10n.statusNoShow, Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}