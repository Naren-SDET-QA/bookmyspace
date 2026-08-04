import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_result_screen.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/payments/presentation/screens/payment_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../payments/mock_payment_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_booking_repository.dart';

Future<void> _pumpThroughPayment(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('paid booking flows hold → pay → success result', (tester) async {
    final bookingRepo = MockBookingRepository();
    final paymentRepo = MockPaymentRepository();
    final checkout = FakeCheckoutService(CheckoutResult.paid);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          paymentRepositoryProvider.overrideWithValue(paymentRepo),
          checkoutServiceProvider.overrideWithValue(checkout),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: createAppRouter(
            initialLocation: AppRoutes.home,
            currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunrise Function Hall').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentScreen), findsOneWidget);
    await tester.tap(find.text('Pay now'));
    await _pumpThroughPayment(tester);

    expect(find.text('Payment successful'), findsOneWidget);
    expect(paymentRepo.lastOrderBookingId, 'b1');
    expect(checkout.lastAmount, 41300);
  });
}
