import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exceptions.dart' as app_errors;
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/checkout_service.dart';
import '../payment_providers.dart';

/// Payment flow: creates a Razorpay order for a freshly made pending booking,
/// opens checkout, then reflects the webhook-driven confirmation.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PaymentPhase { idle, creatingOrder, checkout, verifying, done, error }

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _PaymentPhase _phase = _PaymentPhase.idle;
  String? _errorMessage;
  bool _confirmed = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_phase != _PaymentPhase.idle || widget.booking.totalAmount <= 0) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _phase = _PaymentPhase.creatingOrder);
    try {
      final order = await ref
          .read(paymentRepositoryProvider)
          .createOrder(bookingId: widget.booking.id);
      if (!mounted) return;
      setState(() => _phase = _PaymentPhase.checkout);

      final checkout = ref.read(checkoutServiceProvider);
      final result = await checkout.openCheckout(
        orderId: order.orderId,
        amount: order.amount,
        currency: order.currency,
        keyId: order.keyId ?? AppConfig.razorpayKeyId,
      );
      if (!mounted) return;

      if (result == CheckoutResult.paid) {
        _startVerification();
      } else if (result == CheckoutResult.cancelled) {
        setState(() {
          _phase = _PaymentPhase.idle;
          _errorMessage = l10n.paymentCancelled;
        });
      } else {
        setState(() {
          _phase = _PaymentPhase.error;
          _errorMessage = l10n.paymentFailed;
        });
      }
    } on app_errors.ConfigurationException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(_paymentError(e));
    }
  }

  Future<void> _recoverStatus() async {
    if (!mounted) return;
    setState(() => _phase = _PaymentPhase.verifying);
    try {
      final status = await ref
          .read(paymentRepositoryProvider)
          .bookingStatus(widget.booking.id);
      if (!mounted) return;
      if (status == BookingStatus.confirmed) {
        ref.invalidate(myBookingsProvider);
        setState(() {
          _phase = _PaymentPhase.done;
          _confirmed = true;
        });
      } else if (status == BookingStatus.cancelled) {
        setState(() {
          _phase = _PaymentPhase.error;
          _errorMessage = 'This booking was cancelled and cannot be paid.';
        });
      } else {
        setState(() => _phase = _PaymentPhase.idle);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _PaymentPhase.idle;
        _errorMessage =
            'Could not refresh payment status. Check your connection and retry.';
      });
    }
  }

  String _paymentError(Object error) {
    if (error is app_errors.TimeoutException) {
      return 'Payment service timed out. Check status before trying again.';
    }
    if (error is app_errors.NetworkException) {
      return 'Network interrupted. Check payment status before retrying.';
    }
    if (error is app_errors.ServerException && error.statusCode == 503) {
      return 'Payment service is temporarily unavailable. Check status shortly.';
    }
    if (error is app_errors.AppException) return error.message;
    return 'Payment could not start. Check status and try again.';
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _PaymentPhase.error;
      _errorMessage = message;
    });
  }

  /// After a successful checkout, poll the booking until the webhook has
  /// flipped it to `confirmed` (or a terminal state).
  void _startVerification() {
    setState(() => _phase = _PaymentPhase.verifying);
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      try {
        final status = await ref
            .read(paymentRepositoryProvider)
            .bookingStatus(widget.booking.id);
        if (!mounted) return;
        if (status == BookingStatus.confirmed ||
            status == BookingStatus.cancelled ||
            status == BookingStatus.refunded) {
          timer.cancel();
          ref.invalidate(myBookingsProvider);
          setState(() {
            _phase = _PaymentPhase.done;
            _confirmed = status == BookingStatus.confirmed;
          });
        } else if (attempts > 10) {
          // The webhook may be delayed; hand control back to the user.
          timer.cancel();
          setState(() {
            _phase = _PaymentPhase.done;
            _confirmed = false;
          });
        }
      } catch (_) {
        // Ignore transient polling errors; keep trying.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.payment)),
      body: switch (_phase) {
        _PaymentPhase.idle => _buildIdle(context),
        _PaymentPhase.creatingOrder => const Center(
          child: CircularProgressIndicator(),
        ),
        _PaymentPhase.checkout => const Center(
          child: CircularProgressIndicator(),
        ),
        _PaymentPhase.verifying => _buildVerifying(context, l10n),
        _PaymentPhase.done => _buildDone(context, l10n),
        _PaymentPhase.error => _buildError(context, l10n),
      },
      bottomNavigationBar: _phase == _PaymentPhase.idle
          ? _PayBar(total: widget.booking.totalAmount, onPay: _pay)
          : null,
    );
  }

  Widget _buildIdle(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        _SummaryCard(booking: widget.booking),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildVerifying(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.verifyingPayment,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _confirmed
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_rounded,
              size: 72,
              color: _confirmed ? Colors.green : theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _confirmed ? l10n.paymentSuccess : l10n.paymentPending,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _confirmed
                  ? '${l10n.bookingConfirmed} ${widget.booking.bookingRef}'
                  : l10n.paymentPendingMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_confirmed)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/bookings/${widget.booking.id}/receipt'),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('View receipt'),
              )
            else
              OutlinedButton.icon(
                onPressed: _recoverStatus,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check payment status'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                ref.invalidate(myBookingsProvider);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? l10n.paymentFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _phase = _PaymentPhase.idle),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check status / retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = booking.venueName.isEmpty ? l10n.venues : booking.venueName;

    return Card(
      color: const Color(0xFFF8F6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6DFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat.yMMMd().format(booking.bookDate),
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${booking.displayStart} – ${booking.displayEnd}',
                ),
              ],
            ),
            if (booking.slotLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoChip(icon: Icons.layers_rounded, label: booking.slotLabel),
            ],
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.basePrice,
              value: formatInr(booking.amount),
            ),
            _SummaryRow(
              label: l10n.taxRate,
              value: formatInr(booking.taxAmount),
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.total,
              value: formatInr(booking.totalAmount),
              emphasize: true,
            ),
            const SizedBox(height: 8),
            Text(
              booking.bookingRef,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({required this.total, required this.onPay});

  final double total;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          13,
          AppTheme.pagePadding,
          16,
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.total,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatInr(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.lock_rounded),
                label: Text(l10n.payNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasize
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasize ? AppTheme.brand : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
