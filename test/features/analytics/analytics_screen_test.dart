import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_repository.dart';
import 'package:bookmyspace/features/analytics/domain/revenue_analytics.dart';
import 'package:bookmyspace/features/analytics/presentation/analytics_providers.dart';
import 'package:bookmyspace/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';

class _FakeAnalyticsRepository implements AnalyticsRepository {
  const _FakeAnalyticsRepository(this.data);
  final RevenueAnalytics data;

  @override
  Future<RevenueAnalytics> revenue({
    required DateTime start,
    required DateTime end,
    required bool admin,
  }) async => data;
}

class _EmptyOwnerBookingRepository implements OwnerBookingRepository {
  const _EmptyOwnerBookingRepository();

  @override
  Future<List<Booking>> myVenueBookings() async => const [];

  @override
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) => throw UnimplementedError();

  @override
  Future<Booking> updateStatus(String bookingId, OwnerBookingAction action) =>
      throw UnimplementedError();

  @override
  Future<BookingDecisionOutcome> decideBooking(
    String bookingId,
    OwnerBookingDecision decision,
  ) => throw UnimplementedError();
}

const _data = RevenueAnalytics(
  totalRevenue: 50000,
  successfulBookings: 12,
  cancelledBookings: 1,
  refundAmount: 500,
  netRevenue: 49500,
  averageBookingValue: 4166.67,
  dailyRevenue: [],
  weeklyRevenue: [],
  monthlyRevenue: [],
  bookingTrend: [],
  categoryRevenue: [],
  venueRevenue: [],
);

const _owner = AuthUser(id: 'owner1', email: 'owner@bms.test');

Widget _app() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: _owner),
      ),
      // `revenueAnalyticsProvider` gates on `authStateProvider` (a
      // StreamProvider fed by `authRepositoryProvider.authStateChanges()`),
      // not on `MockAuthRepository.currentUser` directly. The mock's stream
      // never replays `initialUser` to a fresh listener -- only later
      // sign-in/out calls push onto it -- so without this override
      // `authStateProvider` stays in AsyncLoading forever, `user` inside
      // `revenueAnalyticsProvider` is always null, and it throws
      // `StateError('Sign in required')` on every build. That left `query`
      // permanently in an error state, so the share icon (gated on
      // `query.hasValue`) never appeared -- the actual cause of both
      // widget-test failures here, not a production bug.
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
      revenueAnalyticsRepositoryProvider.overrideWithValue(
        const _FakeAnalyticsRepository(_data),
      ),
      ownerBookingRepositoryProvider.overrideWithValue(
        const _EmptyOwnerBookingRepository(),
      ),
    ],
    child: MaterialApp(
      home: const AnalyticsScreen(),
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
  testWidgets('share action is hidden until the report has loaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    // Before the FutureProvider resolves, there is nothing to share yet.
    expect(find.byIcon(Icons.share_rounded), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
  });

  testWidgets(
    'sharing a report offers copy and WhatsApp, and copy puts the summary on the clipboard',
    (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Copy summary'), findsOneWidget);
      // Not tapped here (would hit a real platform channel): the Android
      // reference app's share sheet always offers this action too, and
      // existing invoice-screen tests in this repo take the same approach
      // of asserting the action exists without invoking launchUrl.
      expect(find.text('Share via WhatsApp'), findsOneWidget);

      await tester.tap(find.text('Copy summary'));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('Total revenue: ₹50000.00'));
      expect(copiedText, contains('Successful bookings: 12'));
      expect(find.text('Copied to clipboard'), findsOneWidget);
    },
  );
}
