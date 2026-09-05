import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/profile_screen.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/search/presentation/screens/map_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/mock_auth_repository.dart';
import '../../features/booking/mock_booking_repository.dart';
import '../../features/courses/mock_course_repository.dart';
import '../../features/events/mock_event_repository.dart';
import '../../features/notifications/mock_notification_repository.dart';
import '../../features/venues/mock_venue_repository.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'a@b.com',
  fullName: 'Test Customer',
  phone: '9876543210',
);

List<Override> _baseOverrides({
  MockVenueRepository? venues,
  MockBookingRepository? bookings,
  MockAuthRepository? auth,
}) {
  return [
    venueRepositoryProvider.overrideWithValue(venues ?? MockVenueRepository()),
    authRepositoryProvider.overrideWithValue(
      auth ?? MockAuthRepository(initialUser: _user),
    ),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    notificationRepositoryProvider.overrideWithValue(
      MockNotificationRepository(),
    ),
    if (bookings != null) bookingRepositoryProvider.overrideWithValue(bookings),
  ];
}

Widget _material(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides.isEmpty ? _baseOverrides() : overrides,
    child: MaterialApp(
      home: home,
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
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  testWidgets('defaults expose the four customer sections and discovery chips', (
    tester,
  ) async {
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_lodge_rooms')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_pg_hostels')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('section_institutes_classes')),
      findsOneWidget,
    );
    expect(find.text('View on map'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
  });

  testWidgets('disable PG hides only the PG home tile', (tester) async {
    FeatureRegistry.configure(FeatureId.pg, enabled: false);
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_pg_hostels')), findsNothing);
    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_lodge_rooms')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('section_institutes_classes')),
      findsOneWidget,
    );

    expect(find.text('View on map'), findsOneWidget);
  });

  testWidgets('disable maps hides map entries without crashing search', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('View on map'), findsNothing);
    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);

    await tester.pumpWidget(
      _material(
        const SearchScreen(initialSection: 'function_halls'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('View on map'), findsNothing);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });

  testWidgets('disable voice hides microphone and keeps typed search', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.voice, enabled: false);
    await tester.pumpWidget(
      _material(const SearchScreen(initialSection: 'function_halls')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Voice search'), findsNothing);
    expect(find.byTooltip('View on map'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });

  testWidgets('disable institutes hides institute entries only', (tester) async {
    FeatureRegistry.configure(FeatureId.institutes, enabled: false);
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('section_institutes_classes')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_pg_hostels')), findsOneWidget);

    await tester.pumpWidget(_material(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Payment history'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Support'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Classes'), findsNothing);
  });

  testWidgets('home header follows assistant and notifications flags', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.ai, enabled: false);
    FeatureRegistry.configure(FeatureId.notifications, enabled: false);
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
  });

  testWidgets('disable barcode hides check-in without crashing home', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.barcode, enabled: false);
    await tester.pumpWidget(_material(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);
  });

  testWidgets('profile tiles follow payments, assistant and notifications', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.payments, enabled: false);
    FeatureRegistry.configure(FeatureId.ai, enabled: false);
    FeatureRegistry.configure(FeatureId.notifications, enabled: false);
    await tester.pumpWidget(_material(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Payment history'), findsNothing);
    expect(find.text('AI assistant'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
  });

  testWidgets('map screen does not construct tiles when maps is disabled', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    await tester.pumpWidget(_material(const SearchMapScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('map_unavailable')), findsOneWidget);
  });

  testWidgets('map section chips follow visibleHomeSections', (tester) async {
    FeatureRegistry.configure(FeatureId.pg, enabled: false);
    await tester.pumpWidget(_material(const SearchMapScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '🏠 PG / Hostels'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '🏛️ Function Halls'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '🏨 Lodge / Rooms'), findsOneWidget);
  });

  testWidgets('my bookings hides Pay now when payments is disabled', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.payments, enabled: false);
    final bookings = MockBookingRepository(
      bookings: [MockBookingRepository.sampleBooking()],
    );
    await tester.pumpWidget(
      _material(
        const MyBookingsScreen(),
        overrides: _baseOverrides(bookings: bookings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Cancel booking'), findsOneWidget);
  });

  testWidgets('booking still works and does not open /pay when payments is off', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.payments, enabled: false);
    final bookingRepo = MockBookingRepository();
    final router = createAppRouter(
      initialLocation: '/venues/v1',
      currentUser: _user,
      authReady: true,
      features: FeatureRegistry.instance,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(bookings: bookingRepo),
        child: MaterialApp.router(
          routerConfig: router,
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
    await tester.tap(find.textContaining('Book Now'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'Wedding');
    await tester.pump();
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(bookingRepo.createdBooking, isNotNull);
    expect(router.routeInformationProvider.value.uri.path.endsWith('/pay'), isFalse);
    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Book Your Space'), findsNothing);
  });

  testWidgets('registry configure after mount rebuilds home tiles', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: _baseOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeScreen(),
          localizationsDelegates: [
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
    expect(find.byKey(const ValueKey('section_pg_hostels')), findsOneWidget);

    FeatureRegistry.configure(FeatureId.pg, enabled: false);
    await tester.pump();

    expect(find.byKey(const ValueKey('section_pg_hostels')), findsNothing);
    expect(find.byKey(const ValueKey('section_function_halls')), findsOneWidget);
  });
}
