import 'package:bookmyspace/features/accommodations/domain/accommodation.dart';
import 'package:bookmyspace/features/accommodations/domain/accommodation_repository.dart';
import 'package:bookmyspace/features/accommodations/presentation/accommodation_providers.dart';
import 'package:bookmyspace/features/accommodations/presentation/screens/accommodation_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAccommodationRepository implements AccommodationRepository {
  _FakeAccommodationRepository(this.property, this.availabilityRows);

  final AccommodationProperty property;
  final List<StayUnitAvailability> availabilityRows;

  @override
  Future<List<AccommodationProperty>> search(AccommodationQuery query) async =>
      [property];

  @override
  Future<AccommodationProperty> detail(String propertyId) async => property;

  @override
  Future<String> scheduleVisit({
    required String propertyId,
    required DateTime visitAt,
  }) async =>
      'visit-1';

  @override
  Future<String> reserve(AccommodationReservationRequest request) async =>
      'booking-1';

  @override
  Future<List<StayUnitAvailability>> availability({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
  }) async =>
      availabilityRows;
}

AccommodationProperty _stayProperty({String bookingMode = 'instant'}) {
  return AccommodationProperty(
    id: 'prop-1',
    module: AccommodationModule.stay,
    propertyType: 'hotel',
    name: 'Grand Stay',
    description: 'A fine stay.',
    address: 'Main Road',
    city: 'Ongole',
    amenities: const ['Wi-Fi'],
    foodIncluded: false,
    bookingMode: bookingMode,
    units: [
      AccommodationUnit(
        id: 'deluxe',
        name: 'Deluxe',
        occupancyType: 'double',
        capacity: 2,
        inventory: 2,
        rentMonthly: null,
        priceNightly: 2499,
        deposit: 0,
        availableFrom: DateTime(2026, 8, 1),
        amenities: const [],
      ),
    ],
  );
}

Widget _pump(WidgetTester tester, AccommodationRepository repo) {
  return ProviderScope(
    overrides: [
      accommodationRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: AccommodationDetailScreen(
        propertyId: 'prop-1',
        module: AccommodationModule.stay,
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickDateInPicker(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stay detail renders room types with nightly prices',
      (tester) async {
    final repo = _FakeAccommodationRepository(_stayProperty(), const []);
    await tester.pumpWidget(_pump(tester, repo));
    await tester.pumpAndSettle();

    expect(find.text('Grand Stay'), findsOneWidget);
    await _scrollTo(tester, find.text('Deluxe'));
    expect(find.text('Deluxe'), findsOneWidget);
    expect(find.textContaining('₹2499'), findsOneWidget);
    await _scrollTo(tester, find.text('Reserve'));
    expect(find.text('Reserve'), findsOneWidget);
  });

  testWidgets('reserve without dates or room shows validation snackbar',
      (tester) async {
    final repo = _FakeAccommodationRepository(_stayProperty(), const []);
    await tester.pumpWidget(_pump(tester, repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Reserve'));
    await tester.tap(find.text('Reserve'));
    await tester.pump();
    expect(
      find.text('Select a room and valid dates.'),
      findsOneWidget,
    );
  });

  testWidgets('stay review dialog shows server rate subtotal and mode',
      (tester) async {
    final repo = _FakeAccommodationRepository(
      _stayProperty(),
      const [StayUnitAvailability(unitId: 'deluxe', available: 2, nightlyRate: 3000)],
    );
    await tester.pumpWidget(_pump(tester, repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Deluxe'));
    await tester.tap(find.text('Deluxe'));
    await tester.pump();

    await _scrollTo(tester, find.text('Check-in'));
    await tester.tap(find.text('Check-in'));
    await _pickDateInPicker(tester);
    await _scrollTo(tester, find.text('Reserve'));
    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();

    expect(find.text('Review stay'), findsOneWidget);
    expect(find.textContaining('Subtotal ₹3000'), findsOneWidget);
    expect(find.textContaining('Instant booking'), findsOneWidget);
  });

  testWidgets('approval-mode stay review shows owner approval required',
      (tester) async {
    final repo = _FakeAccommodationRepository(
      _stayProperty(bookingMode: 'approval'),
      const [StayUnitAvailability(unitId: 'deluxe', available: 1, nightlyRate: 2499)],
    );
    await tester.pumpWidget(_pump(tester, repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Deluxe'));
    await tester.tap(find.text('Deluxe'));
    await tester.pump();
    await _scrollTo(tester, find.text('Check-in'));
    await tester.tap(find.text('Check-in'));
    await _pickDateInPicker(tester);
    await _scrollTo(tester, find.text('Reserve'));
    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();

    expect(find.text('Review stay'), findsOneWidget);
    expect(find.textContaining('Owner approval required'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Review stay'), findsNothing);
  });
}
