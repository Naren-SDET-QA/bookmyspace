import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/venues/domain/pg_rent.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/pg_rent_calculator_card.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/venue_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _pgVenue({
  double base = 9000,
  Map<String, dynamic> metadata = const {},
  String slug = 'pg_hostel',
}) {
  return Venue(
    id: 'pg-1',
    name: 'Starlight Ladies PG',
    latitude: 17.45,
    longitude: 78.37,
    pricingBaseAmount: base,
    category: VenueCategory(
      id: 'cat-pg',
      slug: slug,
      name: 'PG',
      metadata: metadata,
    ),
  );
}

const _sharingMeta = {
  'maintenance_fee': 500,
  'security_deposit_months': 1,
  'sharing_options': [
    {
      'id': 'so1',
      'type_name': 'Single Occupancy AC Suite',
      'monthly_rent': 18500,
      'deposit_amount': 18500,
      'room_features': ['Private Bathroom'],
    },
    {
      'id': 'so2',
      'type_name': 'Twin Sharing AC Room',
      'monthly_rent': 12500,
      'deposit_amount': 12500,
    },
    {
      'id': 'so3',
      'type_name': 'Triple Sharing AC Room',
      'monthly_rent': 8500,
      'deposit_amount': 8500,
    },
  ],
};

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('PgRentCalculator', () {
    test('normal calculation matches legacy move-in and tenure totals', () {
      final quote = PgRentCalculator.calculate(
        monthlyRent: 18500,
        deposit: 18500,
        maintenance: 500,
        tenureMonths: 1,
      );
      expect(quote.monthlyBaseRent, 18500);
      expect(quote.securityDeposit, 18500);
      expect(quote.monthlyMaintenanceFee, 500);
      expect(quote.monthlyPayable, 19000);
      expect(quote.totalMoveInCost, 37500);
      expect(quote.totalTenureCost, 37500);
    });

    test('zero and empty values produce a zeroed breakdown', () {
      final empty = PgRentCalculator.calculate();
      expect(empty.monthlyBaseRent, 0);
      expect(empty.securityDeposit, 0);
      expect(empty.monthlyMaintenanceFee, 0);
      expect(empty.totalTenureCost, 0);

      final zeros = PgRentCalculator.calculate(
        monthlyRent: 0,
        deposit: 0,
        maintenance: 0,
        tenureMonths: 1,
      );
      expect(zeros.totalMoveInCost, 0);
      expect(zeros.totalTenureCost, 0);
    });

    test('invalid values are sanitized', () {
      final quote = PgRentCalculator.calculate(
        monthlyRent: -1200,
        deposit: double.nan,
        maintenance: double.infinity,
        tenureMonths: 0,
      );
      expect(quote.monthlyBaseRent, 0);
      expect(quote.securityDeposit, 0);
      expect(quote.monthlyMaintenanceFee, 0);
      expect(quote.tenureMonths, 1);

      expect(PgRentCalculator.sanitizeTenure(-4), 1);
      expect(PgRentCalculator.sanitizeTenure(99), 12);
    });

    test('different tenure durations scale rent and maintenance only', () {
      final one = PgRentCalculator.calculate(
        monthlyRent: 8500,
        deposit: 8500,
        maintenance: 500,
        tenureMonths: 1,
      );
      final six = PgRentCalculator.calculate(
        monthlyRent: 8500,
        deposit: 8500,
        maintenance: 500,
        tenureMonths: 6,
      );
      expect(one.totalRent, 8500);
      expect(six.totalRent, 51000);
      expect(six.securityDeposit, one.securityDeposit);
      expect(six.totalMaintenance, 3000);
      expect(six.totalTenureCost, 51000 + 8500 + 3000);
      expect(six.totalMoveInCost, 8500 + 8500 + 500);
    });

    test('deposit plus maintenance totals use selected sharing option', () {
      const details = PgDetails(
        securityDepositMonths: 1,
        monthlyMaintenanceFee: 500,
        sharingOptions: [
          PgSharingOption(
            id: 'so1',
            typeName: 'Single',
            monthlyRent: 18500,
            depositAmount: 18500,
          ),
          PgSharingOption(
            id: 'so3',
            typeName: 'Triple',
            monthlyRent: 8500,
            depositAmount: 8500,
          ),
        ],
      );

      final single = PgRentCalculator.fromDetails(
        details,
        selectedOptionIndex: 0,
        tenureMonths: 3,
      );
      expect(single.monthlyBaseRent, 18500);
      expect(single.securityDeposit, 18500);
      expect(single.totalMaintenance, 1500);
      expect(single.totalTenureCost, 18500 * 3 + 18500 + 1500);

      final triple = PgRentCalculator.fromDetails(
        details,
        selectedOptionIndex: 1,
        tenureMonths: 3,
      );
      expect(triple.monthlyBaseRent, 8500);
      expect(triple.securityDeposit, 8500);
      expect(triple.totalTenureCost, 8500 * 3 + 8500 + 1500);
    });

    test('venue without PG extras falls back to base rent as deposit', () {
      final venue = _pgVenue(base: 9000);
      final quote = PgRentCalculator.fromVenue(venue, tenureMonths: 2);
      expect(quote.monthlyBaseRent, 9000);
      expect(quote.securityDeposit, 9000);
      expect(quote.monthlyMaintenanceFee, 0);
      expect(quote.totalTenureCost, 18000 + 9000);
    });

    test('out-of-range sharing index uses the first option', () {
      const details = PgDetails(
        sharingOptions: [
          PgSharingOption(
            id: 'so1',
            typeName: 'Single',
            monthlyRent: 18500,
            depositAmount: 18500,
          ),
        ],
      );
      final quote = PgRentCalculator.fromDetails(
        details,
        selectedOptionIndex: 9,
        fallbackBase: 9000,
      );
      expect(quote.monthlyBaseRent, 18500);
    });

    test('reads sharing options from category metadata', () {
      final venue = _pgVenue(metadata: _sharingMeta);
      final details = PgDetails.tryFromVenue(venue);
      expect(details, isNotNull);
      expect(details!.sharingOptions, hasLength(3));
      expect(details.maintenanceFee, 500);

      final quote = PgRentCalculator.fromVenue(
        venue,
        selectedOptionIndex: 2,
        tenureMonths: 1,
      );
      expect(quote.monthlyBaseRent, 8500);
      expect(quote.securityDeposit, 8500);
      expect(quote.monthlyMaintenanceFee, 500);
    });
  });

  group('PgRentCalculatorCard', () {
    testWidgets('renders breakdown for a PG venue and updates tenure', (
      tester,
    ) async {
      final venue = _pgVenue(metadata: _sharingMeta);
      await tester.pumpWidget(_wrap(PgRentCalculatorCard(venue: venue)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pg_rent_calculator')), findsOneWidget);
      expect(find.text('Monthly rent calculator'), findsOneWidget);
      expect(find.text('Single Occupancy AC Suite'), findsOneWidget);
      expect(find.text(formatInr(37500)), findsWidgets);

      final slider = tester.widget<Slider>(
        find.byKey(const Key('pg_rent_tenure_slider')),
      );
      slider.onChanged!(6);
      await tester.pump();

      const sixMonthTotal = 18500 * 6 + 18500 + 500 * 6;
      expect(find.text(formatInr(sixMonthTotal.toDouble())), findsOneWidget);
    });

    testWidgets('switching sharing option updates deposit and rent', (
      tester,
    ) async {
      final venue = _pgVenue(metadata: _sharingMeta);
      await tester.pumpWidget(_wrap(PgRentCalculatorCard(venue: venue)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pg_sharing_2')));
      await tester.pump();

      expect(find.text(formatInr(17500)), findsWidgets);
    });

    testWidgets('does not render for non-PG venues', (tester) async {
      final hall = _pgVenue(slug: 'function_hall');
      await tester.pumpWidget(_wrap(PgRentCalculatorCard(venue: hall)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pg_rent_calculator')), findsNothing);
    });
  });
}
