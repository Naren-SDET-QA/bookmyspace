import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';

/// Dedicated booking confirmation screen shown once a payment is verified
/// as confirmed by the backend webhook.
///
/// Parity note: the Android reference app navigates to a distinct
/// `BookingSuccessScreen` after payment (booking reference with
/// copy-to-clipboard, a venue/date summary, a real price breakdown, and
/// clear next steps) instead of a brief inline message. This mirrors that
/// shape using only data already present on the confirmed [Booking] --
/// nothing here is invented; the advance/balance-due split shown on the
/// Android screen is intentionally not reproduced because the Flutter
/// booking model (and backend) has no partial/advance-payment concept to
/// report honestly.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 88,
                  color: Colors.green.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.bookingSuccessTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (booking.venueName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                booking.venueName,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.bookingRef,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            booking.bookingRef,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.copy,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: booking.bookingRef),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.copiedToClipboard)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.slotLabel.isNotEmpty)
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        text: booking.slotLabel,
                      ),
                    if (booking.slotLabel.isNotEmpty)
                      const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.event_rounded,
                      text: DateFormat.yMMMd().format(booking.bookDate),
                    ),
                    if (booking.venueCity.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.place_rounded,
                        text: booking.venueCity,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.brand.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PriceRow(
                      label: l10n.basePrice,
                      value: formatInr(booking.amount),
                    ),
                    _PriceRow(
                      label: l10n.taxRate,
                      value: formatInr(booking.taxAmount),
                    ),
                    if (booking.discountAmount > 0)
                      _PriceRow(
                        label: l10n.discount,
                        value: '-${formatInr(booking.discountAmount)}',
                      ),
                    const Divider(height: 24),
                    _PriceRow(
                      label: l10n.total,
                      value: formatInr(booking.totalAmount),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
            if (booking.paymentMethod.isNotEmpty ||
                booking.paymentRef.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PriceRow(
                        label: l10n.payMethod,
                        value: booking.isOffline
                            ? l10n.offlinePayment
                            : l10n.onlinePayment,
                      ),
                      if (booking.paymentRef.isNotEmpty)
                        _PriceRow(
                          label: l10n.paymentRef,
                          value: booking.paymentRef,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/bookings/${booking.id}/invoice'),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(l10n.viewInvoice),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                context.go(AppRoutes.bookings);
              },
              child: Text(l10n.myBookings),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.go(AppRoutes.home);
              },
              child: Text(l10n.exploreMoreSpaces),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: emphasize
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
