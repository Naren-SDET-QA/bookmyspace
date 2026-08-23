import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/theme/theme_tokens.dart';
import 'package:bookmyspace/features/booking/domain/configurable_booking.dart';
import 'package:bookmyspace/features/booking/domain/invoice_repository.dart';
import 'package:bookmyspace/features/checkin/domain/check_in.dart';
import 'package:bookmyspace/features/home/presentation/widgets/category_carousel.dart';
import 'package:bookmyspace/features/offers/domain/offer_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_discovery.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown database category works from metadata only', () {
    final config = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: 'new',
        slug: 'floating_pavilion',
        name: 'Floating Pavilion',
        metadata: {
          'section': 'function_halls',
          'bookable': true,
          'searchable': true,
          'home_visible': true,
          'offer_visible': true,
          'theme_color': '#1565C0',
          'booking_required_fields': ['date', 'time', 'guests'],
          'booking_optional_fields': ['notes'],
          'sort_order': 4,
        },
      ),
    );
    expect(config.slug, 'floating_pavilion');
    expect(config.bookable, isTrue);
    expect(config.searchable, isTrue);
    expect(config.homeVisible, isTrue);
    expect(config.offerVisible, isTrue);
    expect(config.themeColor, '#1565C0');
    expect(config.bookingRequiredFields, ['date', 'time', 'guests']);
    expect(config.bookingOptionalFields, ['notes']);
  });

  test('disabled category is hidden from discovery', () {
    final hidden = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: '2',
        slug: 'secret_hall',
        name: 'Secret Hall',
        metadata: {'active': false, 'home_visible': true},
      ),
    );
    final shown = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: '1',
        slug: 'open_hall',
        name: 'Open Hall',
        metadata: {'active': true, 'home_visible': true},
      ),
    );
    final visible = CategoryDiscovery.homeVisible([hidden, shown]);
    expect(visible.map((item) => item.slug), ['open_hall']);
    expect(hidden.visible, isFalse);
  });

  test(
    'category configuration controls booking fields without slug switches',
    () {
      const hall = CategoryConfiguration(
        id: 'h',
        slug: 'function_hall',
        name: 'Hall',
        bookingRequiredFields: ['date', 'time', 'guests'],
      );
      const hotel = CategoryConfiguration(
        id: 'o',
        slug: 'boutique_stay',
        name: 'Boutique Stay',
        bookingRequiredFields: ['check_in', 'check_out', 'guests'],
      );
      const pg = CategoryConfiguration(
        id: 'p',
        slug: 'coliving_pod',
        name: 'Coliving Pod',
        bookingRequiredFields: ['move_in', 'duration', 'occupants'],
      );
      const course = CategoryConfiguration(
        id: 'c',
        slug: 'robotics_lab',
        name: 'Robotics Lab',
        bookable: true,
        bookingRequiredFields: ['course', 'schedule', 'student_name'],
      );
      const event = CategoryConfiguration(
        id: 'e',
        slug: 'night_market',
        name: 'Night Market',
        bookingRequiredFields: ['event_session', 'ticket_quantity'],
      );

      expect(ConfigurableBookingFields.from(hall).map((field) => field.key), [
        'date',
        'time',
        'guests',
      ]);
      expect(ConfigurableBookingFields.from(hotel).map((field) => field.key), [
        'check_in',
        'check_out',
        'guests',
      ]);
      expect(ConfigurableBookingFields.from(pg).map((field) => field.key), [
        'move_in',
        'duration',
        'occupants',
      ]);
      expect(ConfigurableBookingFields.from(course).map((field) => field.key), [
        'course',
        'schedule',
        'student_name',
      ]);
      expect(ConfigurableBookingFields.from(event).map((field) => field.key), [
        'event_session',
        'ticket_quantity',
      ]);
      expect(
        ConfigurableBookingFields.resolve(
          sectionId: 'events',
        ).map((field) => field.key),
        ['event_session', 'ticket_quantity'],
      );
      expect(
        ConfigurableBookingFields.resolve(
          sectionId: 'courses',
        ).map((field) => field.key),
        ['schedule', 'student_name'],
      );
    },
  );

  test(
    'one universal booking draft works with different category metadata',
    () {
      const specs = [
        BookingFieldSpec(key: 'check_in', required: true),
        BookingFieldSpec(key: 'check_out', required: true),
        BookingFieldSpec(key: 'guests', required: true),
        BookingFieldSpec(key: 'notes', required: false),
      ];
      final incomplete = BookingFieldValues({
        'check_in': '2026-09-01',
        'guests': 2,
      });
      expect(incomplete.missing(specs), ['check_out']);

      final complete = BookingFieldValues({
        'check_in': '2026-09-01',
        'check_out': '2026-09-03',
        'guests': 2,
      });
      expect(complete.missing(specs), isEmpty);
      expect(complete.toMetadata()['check_in'], '2026-09-01');
    },
  );

  test('non-bookable configured category stays listing-only', () {
    const listing = CategoryConfiguration(
      id: 'i',
      slug: 'open_campus',
      name: 'Open Campus',
      bookable: false,
    );
    expect(listing.isListingOnly, isTrue);
    expect(ConfigurableBookingFields.from(listing), isEmpty);
  });

  test('category carousel remains bounded and skips hidden items', () {
    final items = [
      for (var i = 0; i < 80; i++)
        CategoryConfiguration(
          id: '$i',
          slug: 'cat_$i',
          name: 'Cat $i',
          homeVisible: i.isEven,
          visible: true,
        ),
    ];
    final carousel = CategoryDiscovery.carouselItems(items);
    expect(
      carousel.length,
      lessThanOrEqualTo(CategoryDiscovery.maxCarouselItems),
    );
    expect(carousel.every((item) => item.homeVisible && item.visible), isTrue);
  });

  testWidgets('category carousel lazily builds a bounded horizontal list', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 12; i++)
        CategoryConfiguration(
          id: '$i',
          slug: 'c$i',
          name: 'Chip $i',
          homeVisible: true,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryCarousel(
            items: items,
            selectedId: '0',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Chip 0'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(-200, 0));
    await tester.pump();
  });

  test('offer configuration is generic and can target category or listing', () {
    final offer = OfferConfiguration.fromJson({
      'id': 'off-1',
      'code': 'FESTIVE10',
      'description': 'Festive 10%',
      'discount_type': 'percentage',
      'discount_value': 10,
      'is_active': true,
      'starts_at': '2026-08-01T00:00:00Z',
      'ends_at': '2026-08-31T00:00:00Z',
      'metadata': {
        'title': 'Festive 10%',
        'category_ids': ['cat-hall'],
        'listing_ids': ['v1'],
      },
    });
    expect(offer.enabled, isTrue);
    expect(offer.title, 'Festive 10%');
    expect(offer.isPercentage, isTrue);
    expect(offer.discountValue, 10);
    expect(offer.appliesTo(categoryId: 'cat-hall', listingId: 'v9'), isTrue);
    expect(offer.appliesTo(categoryId: 'other', listingId: 'v2'), isFalse);
  });

  test('invoice artifact keeps PDF and adds notification status', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice': {'invoice_number': 'BMS-2026-ABC123'},
      'signed_url': 'https://example.test/signed-invoice',
      'email_queued': true,
      'notification_queued': true,
    });
    expect(invoice.invoiceNumber, 'BMS-2026-ABC123');
    expect(invoice.signedUrl, isNotNull);
    expect(invoice.emailQueued, isTrue);
    expect(invoice.notificationQueued, isTrue);
    expect(invoice.canOpenPdf, isTrue);
    expect(invoice.canShare, isTrue);
  });

  test('existing barcode check-in behavior is unchanged', () {
    final result = CheckInResult.fromJson({
      'ok': true,
      'booking_id': 'b1',
      'check_in_id': 'c1',
    });
    expect(result.ok, isTrue);
    expect(FeatureRegistry.defaults().isEnabled(FeatureId.barcode), isTrue);
  });

  test('theme tokens stay centralized for light and dark', () {
    final light = ThemeTokens.fromSeed(const Color(0xFF3F51B5));
    final dark = ThemeTokens.fromSeed(
      const Color(0xFF3F51B5),
      brightness: Brightness.dark,
    );
    expect(light.primary, const Color(0xFF3F51B5));
    expect(light.secondary.value, isNonZero);
    expect(dark.surface, isNot(light.surface));
  });
}
