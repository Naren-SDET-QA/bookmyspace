import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/booking.dart';

/// Visible countdown driven by the server hold-expiry timestamp.
///
/// Expiry here is display-only. The server still rejects stale holds.
class BookingHoldCountdown extends StatefulWidget {
  const BookingHoldCountdown({
    super.key,
    required this.expiresAt,
    this.now,
    this.onExpired,
  });

  final DateTime expiresAt;
  final DateTime Function()? now;
  final VoidCallback? onExpired;

  @override
  State<BookingHoldCountdown> createState() => _BookingHoldCountdownState();
}

class _BookingHoldCountdownState extends State<BookingHoldCountdown> {
  Timer? _timer;
  var _expiredNotified = false;
  late Duration _remaining;

  DateTime _clock() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _remaining = BookingHold(
      id: 'hold',
      expiresAt: widget.expiresAt,
    ).remaining(_clock());
    if (_remaining == Duration.zero) {
      _expiredNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onExpired?.call();
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final remaining = BookingHold(
      id: 'hold',
      expiresAt: widget.expiresAt,
    ).remaining(_clock());
    if (!mounted) return;
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero && !_expiredNotified) {
      _expiredNotified = true;
      _timer?.cancel();
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = _remaining == Duration.zero;
    return Semantics(
      liveRegion: true,
      label: expired
          ? 'Hold expired'
          : 'Hold expires in ${HoldCountdown.format(_remaining)}',
      child: Container(
        key: const Key('booking_hold_countdown'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (expired ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer)
              .withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              expired ? Icons.timer_off_rounded : Icons.timer_rounded,
              size: 20,
              color: expired
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expired
                    ? 'This hold has expired. Pick the slot again.'
                    : 'Hold expires in ${HoldCountdown.format(_remaining)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: expired
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
