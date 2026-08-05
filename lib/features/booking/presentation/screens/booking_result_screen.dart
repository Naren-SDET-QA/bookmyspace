import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../domain/booking.dart';

class BookingResultScreen extends StatefulWidget {
  const BookingResultScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<BookingResultScreen> createState() => _BookingResultScreenState();
}

class _BookingResultScreenState extends State<BookingResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _pop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final waiting = booking.status == BookingStatus.requested;
    final confirmed = booking.status == BookingStatus.confirmed;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              24,
              AppTheme.pagePadding,
              24,
            ),
            children: [
              const SizedBox(height: 16),
              // Animated success check (prototype `.succCk` pop).
              Center(
                child: ScaleTransition(
                  scale: _pop,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brand.withValues(alpha: 0.4),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      waiting
                          ? Icons.hourglass_top_rounded
                          : confirmed
                          ? Icons.check_rounded
                          : Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                waiting ? 'Waiting for owner approval' : 'Booking confirmed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                waiting
                    ? 'We’ll notify you as soon as the owner responds. Payment starts only after approval.'
                    : 'Your space is reserved. You can find the receipt and updates in My Bookings.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              // Ticket card (prototype `.tkt`).
              _TicketCard(booking: booking, waiting: waiting),
              const SizedBox(height: 26),
              PrototypeButton(
                label: 'View my bookings',
                onPressed: () => context.go(AppRoutes.bookings),
                icon: Icons.event_note_rounded,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.home),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Back to home',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking, required this.waiting});

  final Booking booking;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.venueName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DateFormat.yMMMd().format(booking.bookDate)} · '
                        '${booking.displayStart}–${booking.displayEnd}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _FakeQr(seed: booking.bookingRef),
              ],
            ),
          ),
          // Dashed perforation (prototype `.tkDiv`).
          const _Perforation(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.bookingRef,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppTheme.brand,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Show this at entry',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: waiting
                        ? const Color(0xFFFDF3E0)
                        : PrototypeVisuals.availBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    waiting ? 'PENDING APPROVAL' : 'CONFIRMED',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: waiting ? const Color(0xFFB45309) : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed divider with side notches (prototype `.tkDiv:before/:after`).
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: const CustomPaint(painter: _DashPainter(color: AppTheme.line)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// Deterministic placeholder QR (prototype `qr(seed)`).
class _FakeQr extends StatelessWidget {
  const _FakeQr({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: CustomPaint(
        size: const Size(52, 52),
        painter: _QrPainter(seed: h),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.ink;
    const n = 9;
    final cell = size.width / n;
    var rng = seed;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        rng = (rng * 31 + r * 7 + c * 13) & 0x7fffffff;
        if (rng % 3 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell, r * cell, cell - 1, cell - 1),
              const Radius.circular(1.5),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.seed != seed;
}
