import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/notifications/domain/notification.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/payments/presentation/screens/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}) {
  return ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(paymentRepo),
      checkoutServiceProvider.overrideWithValue(checkout),
      notificationRepositoryProvider.overrideWithValue(
        notificationRepo ?? MockNotificationRepository(),
      ),
    ],
    child: MaterialApp(
      home: PaymentScreen(booking: _booking),
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

    expect(find.text('Payment successful'), findsOneWidget);
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
}
