import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/invoice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_booking_repository.dart';

Booking _offlineBooking() {
  return Booking(
    id: 'b1',
    bookingRef: 'BMS-OFF01',
    venueId: 'v1',
    slotId: 's1',
    bookDate: DateTime(2026, 9, 1),
    startTime: '09:00:00',
    endTime: '13:00:00',
    status: BookingStatus.confirmed,
    amount: 35000,
    taxAmount: 6300,
    totalAmount: 41300,
    venueName: 'Sunrise Function Hall',
    venueCity: 'Hyderabad',
    slotLabel: 'Morning',
    customerName: 'Ravi Kumar',
    customerPhone: '9876543210',
    isOffline: true,
    paymentMethod: 'offline',
    paymentRef: 'OFF-001',
    paidAt: DateTime(2026, 8, 18, 10, 30),
    metadata: const {
      'guests': 120,
      'checkout_date': '2026-09-01T18:00:00Z',
      'sharing': 2,
      'deposit': 10000,
    },
  );
}

Widget _app(MockBookingRepository bookingRepo, {Booking? initial}) {
  return ProviderScope(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(bookingRepo),
    ],
    child: MaterialApp(
      home: InvoiceScreen(bookingId: 'b1', initial: initial),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('renders invoice details from the initial booking', (
    tester,
  ) async {
    final booking = _offlineBooking();
    await tester.pumpWidget(
      _app(MockBookingRepository(bookings: [booking]), initial: booking),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('BMS-OFF01'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);

    // Lower sections sit below the fold; scroll through them in order.
    await tester.scrollUntilVisible(
      find.text('₹10,000'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('120'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('₹10,000'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('₹41,300'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('₹41,300'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('OFF-001'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Offline (walk-in)'), findsOneWidget);
    expect(find.text('OFF-001'), findsOneWidget);
  });

  testWidgets('refreshes the booking from the repository when only an id is given', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository(
      bookings: [MockBookingRepository.sampleBooking(status: BookingStatus.confirmed)],
    );
    await tester.pumpWidget(_app(bookingRepo));
    await tester.pumpAndSettle();

    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('BMS-1A2B3C'), findsOneWidget);
    expect(find.text('₹41,300'), findsWidgets);
  });
}