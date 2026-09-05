import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/widgets/booking_hold_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HoldCountdown formats remaining time and treats expiry as zero', () {
    expect(HoldCountdown.format(const Duration(minutes: 1, seconds: 5)), '01:05');
    expect(HoldCountdown.format(Duration.zero), '00:00');
    final hold = BookingHold(
      id: 'h1',
      expiresAt: DateTime(2026, 9, 1, 12, 10),
    );
    expect(hold.remaining(DateTime(2026, 9, 1, 12, 9)), const Duration(minutes: 1));
    expect(hold.isExpired(DateTime(2026, 9, 1, 12, 10)), isTrue);
  });

  test('BookingHold prefers the server expires_at timestamp', () {
    final hold = BookingHold.fromResponse({
      'hold_id': 'hold-1',
      'expires_in_minutes': 10,
      'expires_at': '2026-09-01T12:10:00.000Z',
    }, now: DateTime.utc(2026, 9, 1, 12));
    expect(hold.id, 'hold-1');
    expect(hold.expiresAt.toUtc(), DateTime.utc(2026, 9, 1, 12, 10));
  });

  testWidgets('countdown shows remaining time then expires', (tester) async {
    var now = DateTime(2026, 9, 1, 12, 0, 0);
    var expired = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BookingHoldCountdown(
            expiresAt: DateTime(2026, 9, 1, 12, 0, 2),
            now: () => now,
            onExpired: () => expired = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BookingHoldCountdown), findsOneWidget);
    expect(find.textContaining('00:02'), findsOneWidget);

    now = DateTime(2026, 9, 1, 12, 0, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('expired'), findsOneWidget);
    expect(expired, isTrue);
  });
}
