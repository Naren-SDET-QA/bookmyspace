import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/notifications/domain/notification.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/payments/presentation/screens/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../booking/mock_booking_repository.dart';
import '../notifications/mock_notification_repository.dart';
import 'mock_payment_repository.dart';

final _booking = Booking(
  id: 'b1',
  bookingRef: 'BMS-1A2B3C',
  venueId: 'v1',
  slotId: 's1',
  bookDate: DateTime(2026, 9, 1),
  startTime: '09:00:00',
  endTime: '13:00:00',
  status: BookingStatus.pending,
  amount: 35000,
  taxAmount: 6300,
  totalAmount: 41300,
  venueName: 'Sunrise Function Hall',
  slotLabel: 'Morning',
);

Widget _app(
  MockPaymentRepository paymentRepo,
  FakeCheckoutService checkout, {
  MockNotificationRepository? notificationRepo,
  MockBookingRepository? bookingRepo,
  Booking? booking,
}) {
  return ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(paymentRepo),
      checkoutServiceProvider.overrideWithValue(checkout),
      notificationRepositoryProvider.overrideWithValue(
        notificationRepo ?? MockNotificationRepository(),
      ),
      if (bookingRepo != null)
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
    ],
    child: MaterialApp(
      home: PaymentScreen(booking: booking ?? _booking),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Steps the widget through the payment phases, avoiding pumpAndSettle
/// because the intermediate phases show an infinite progress spinner.
Future<void> _pumpThroughPayment(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows the booking summary and total', (tester) async {
    await tester.pumpWidget(
      _app(MockPaymentRepository(), FakeCheckoutService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('₹41,300'), findsWidgets);
    expect(find.text('Pay now'), findsOneWidget);
  });

  testWidgets('paying creates an order and opens checkout', (tester) async {
    final paymentRepo = MockPaymentRepository();
    final checkout = FakeCheckoutService(CheckoutResult.paid);
    await tester.pumpWidget(_app(paymentRepo, checkout));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(paymentRepo.lastOrderBookingId, 'b1');
    expect(checkout.lastOrderId, 'order_1');
    expect(checkout.lastAmount, 41300);
    expect(checkout.lastCurrency, 'INR');
  });

  testWidgets('a successful checkout verifies and confirms', (tester) async {
    final paymentRepo = MockPaymentRepository();
    final notificationRepo = MockNotificationRepository();
    await tester.pumpWidget(
      _app(
        paymentRepo,
        FakeCheckoutService(CheckoutResult.paid),
        notificationRepo: notificationRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    // A confirmed booking gets the full dedicated success screen (parity
    // with the Android reference app's BookingSuccessScreen) rather than
    // the old inline "Payment successful" card.
    expect(find.text('Booking Confirmed!'), findsOneWidget);
    expect(find.text('BMS-1A2B3C'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsWidgets);
    expect(find.text('Payment successful'), findsNothing);
    expect(paymentRepo.statusCalls, greaterThan(0));

    // The confirmed booking records an in-app notification.
    await tester.pump();
    expect(notificationRepo.created, hasLength(1));
    expect(
      notificationRepo.created.single.type,
      NotificationType.bookingConfirmed,
    );
  });

  testWidgets('a cancelled checkout returns to the pay screen', (tester) async {
    await tester.pumpWidget(
      _app(
        MockPaymentRepository(),
        FakeCheckoutService(CheckoutResult.cancelled),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(find.text('Pay now'), findsOneWidget);
    expect(find.textContaining('cancelled'), findsOneWidget);
  });

  testWidgets('a failed checkout shows an error', (tester) async {
    await tester.pumpWidget(
      _app(MockPaymentRepository(), FakeCheckoutService(CheckoutResult.failed)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(find.text('Payment failed'), findsWidgets);
  });

  testWidgets('a checkout timeout exits loading without retrying the order', (
    tester,
  ) async {
    final paymentRepo = MockPaymentRepository();
    await tester.pumpWidget(
      _app(paymentRepo, FakeCheckoutService(CheckoutResult.timedOut)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(find.textContaining('timed out'), findsOneWidget);
    expect(paymentRepo.lastOrderBookingId, 'b1');
    expect(find.text('Pay now'), findsNothing);
  });

  testWidgets('order creation failure surfaces an error', (tester) async {
    final paymentRepo = MockPaymentRepository()..failCreateOrder = true;
    await tester.pumpWidget(_app(paymentRepo, FakeCheckoutService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(find.textContaining('order creation failed'), findsOneWidget);
  });

  group('promo code', () {
    testWidgets('applying a valid promo updates the summary and pay bar', (
      tester,
    ) async {
      final bookingRepo = MockBookingRepository(bookings: [_booking]);
      await tester.pumpWidget(
        _app(
          MockPaymentRepository(),
          FakeCheckoutService(),
          bookingRepo: bookingRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Base 41,300 before any promo.
      expect(find.text('₹41,300'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'WELCOME10');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // 10% of 41,300 = 4,130 -> new total 37,170, shown in the summary
      // card and the sticky pay bar.
      expect(find.textContaining('Promo applied: WELCOME10'), findsOneWidget);
      expect(find.text('- ₹4,130'), findsOneWidget);
      expect(find.text('₹37,170'), findsWidgets);
      expect(find.text('₹41,300'), findsNothing);
    });

    testWidgets('an invalid promo shows an inline error and changes nothing', (
      tester,
    ) async {
      final bookingRepo = MockBookingRepository(bookings: [_booking]);
      await tester.pumpWidget(
        _app(
          MockPaymentRepository(),
          FakeCheckoutService(),
          bookingRepo: bookingRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NOPE123');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('coupon_not_found'), findsOneWidget);
      expect(find.text('₹41,300'), findsWidgets);
      expect(find.textContaining('Promo applied'), findsNothing);
    });

    testWidgets('removing an applied promo restores the original total', (
      tester,
    ) async {
      final bookingRepo = MockBookingRepository(bookings: [_booking]);
      await tester.pumpWidget(
        _app(
          MockPaymentRepository(),
          FakeCheckoutService(),
          bookingRepo: bookingRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'WELCOME10');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('₹37,170'), findsWidgets);

      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('₹41,300'), findsWidgets);
      expect(find.textContaining('Promo applied'), findsNothing);
    });

    testWidgets(
      'paying after a promo only ever sends the booking id — the charge '
      'amount is whatever create-payment-order reads from the DB row the '
      'promo already updated, never a client-supplied number',
      (tester) async {
        final bookingRepo = MockBookingRepository(bookings: [_booking]);
        final paymentRepo = MockPaymentRepository();
        await tester.pumpWidget(
          _app(
            paymentRepo,
            FakeCheckoutService(),
            bookingRepo: bookingRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'WELCOME10');
        await tester.ensureVisible(find.text('Apply'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pay now'));
        await _pumpThroughPayment(tester);

        expect(paymentRepo.lastOrderBookingId, 'b1');
      },
    );
  });

  group('pay at venue', () {
    testWidgets('both payment options are shown, online selected by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(MockPaymentRepository(), FakeCheckoutService()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Online (Razorpay)'), findsOneWidget);
      expect(find.text('Pay at venue'), findsOneWidget);
      expect(find.text('Pay now'), findsOneWidget);
      expect(find.text('Confirm booking'), findsNothing);
    });

    testWidgets(
      'selecting Pay at Venue swaps the confirm button, still without '
      'touching the server',
      (tester) async {
        final paymentRepo = MockPaymentRepository();
        await tester.pumpWidget(_app(paymentRepo, FakeCheckoutService()));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Pay at venue'));
        await tester.tap(find.text('Pay at venue'));
        await tester.pumpAndSettle();

        expect(find.text('Confirm booking'), findsOneWidget);
        expect(find.text('Pay now'), findsNothing);
        expect(paymentRepo.lastPayAtVenueBookingId, isNull);
        expect(paymentRepo.lastOrderBookingId, isNull);
      },
    );

    testWidgets(
      'confirming Pay at Venue commits the booking server-side and never '
      'creates a Razorpay order or opens checkout',
      (tester) async {
        final paymentRepo = MockPaymentRepository();
        final checkout = FakeCheckoutService(CheckoutResult.paid);
        await tester.pumpWidget(_app(paymentRepo, checkout));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Pay at venue'));
        await tester.tap(find.text('Pay at venue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm booking'));
        await _pumpThroughPayment(tester);

        expect(paymentRepo.lastPayAtVenueBookingId, 'b1');
        // Pay-at-venue must NOT create a Razorpay payment/order.
        expect(paymentRepo.lastOrderBookingId, isNull);
        expect(checkout.lastOrderId, isNull);

        // Pay-at-venue never auto-confirms — it lands in the same
        // owner-approval queue a captured online payment reaches, so the
        // screen shows the pending-approval state, not "successful".
        expect(find.text('Payment pending'), findsOneWidget);
        expect(find.text('Payment successful'), findsNothing);
      },
    );

    testWidgets(
      'a server-side rejection (e.g. another payment already in progress) '
      'surfaces the error and still creates no order',
      (tester) async {
        final paymentRepo = MockPaymentRepository()
          ..failSelectPayAtVenue = true
          ..payAtVenueError = const BusinessException(
            'A payment for this booking is already in progress.',
            code: 'payment_in_progress',
          );
        final checkout = FakeCheckoutService();
        await tester.pumpWidget(_app(paymentRepo, checkout));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Pay at venue'));
        await tester.tap(find.text('Pay at venue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm booking'));
        await _pumpThroughPayment(tester);

        expect(find.textContaining('payment_in_progress'), findsOneWidget);
        expect(paymentRepo.lastOrderBookingId, isNull);
        expect(checkout.lastOrderId, isNull);
      },
    );

    testWidgets(
      'pay-at-venue still charges the promo-discounted total, exactly like '
      'the online flow — the server, not the client, reads the amount',
      (tester) async {
        final bookingRepo = MockBookingRepository(bookings: [_booking]);
        final paymentRepo = MockPaymentRepository();
        await tester.pumpWidget(
          _app(paymentRepo, FakeCheckoutService(), bookingRepo: bookingRepo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'WELCOME10');
        await tester.ensureVisible(find.text('Apply'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('₹37,170'), findsWidgets);

        await tester.ensureVisible(find.text('Pay at venue'));
        await tester.tap(find.text('Pay at venue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm booking'));
        await _pumpThroughPayment(tester);

        // Only the booking id crosses the wire; select_pay_at_venue reads
        // bookings.total_amount (already discounted) itself.
        expect(paymentRepo.lastPayAtVenueBookingId, 'b1');
      },
    );
  });
}
