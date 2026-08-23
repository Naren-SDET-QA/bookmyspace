import 'package:bookmyspace/core/modular/feature_config.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/features/ai/domain/booking_intent.dart';
import 'package:bookmyspace/features/booking/domain/configurable_booking.dart';
import 'package:bookmyspace/features/booking/domain/invoice_display_config.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_discovery.dart';
import 'package:bookmyspace/features/venues/domain/category_filter_catalog.dart';
import 'package:bookmyspace/features/venues/domain/category_registration.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search chips hide disabled and non-searchable categories', () {
    const hidden = CategoryConfiguration(
      id: '1',
      slug: 'secret_hall',
      name: 'Secret Hall',
      sectionId: 'function_halls',
      searchable: false,
    );
    const inactive = CategoryConfiguration(
      id: '2',
      slug: 'closed_hall',
      name: 'Closed Hall',
      sectionId: 'function_halls',
      visible: false,
    );
    const shown = CategoryConfiguration(
      id: '3',
      slug: 'marriage_hall',
      name: 'Marriage Hall',
      sectionId: 'function_halls',
      searchable: true,
      sortOrder: 2,
    );
    const otherSection = CategoryConfiguration(
      id: '4',
      slug: 'hotel',
      name: 'Hotel',
      sectionId: 'lodge_rooms',
    );

    expect(
      CategoryDiscovery.searchChips(const [
        hidden,
        inactive,
        shown,
        otherSection,
      ], sectionId: 'function_halls').map((c) => c.slug),
      ['marriage_hall'],
    );
  });

  test('search filter sheet categories ignore hardcoded catalog fallbacks', () {
    const hiddenCatalog = CategoryConfiguration(
      id: '1',
      slug: 'marriage_hall',
      name: 'Marriage Hall',
      sectionId: 'function_halls',
      searchable: false,
    );
    const unknown = CategoryConfiguration(
      id: '2',
      slug: 'floating_pavilion',
      name: 'Floating Pavilion',
      sectionId: 'function_halls',
      searchable: true,
      sortOrder: 1,
    );
    expect(
      CategoryDiscovery.searchFilterCategories(const [
        hiddenCatalog,
        unknown,
      ], sectionId: 'function_halls').map((c) => c.slug),
      ['floating_pavilion'],
    );
    expect(
      CategoryDiscovery.searchFilterCategories(const [
        hiddenCatalog,
      ], sectionId: 'function_halls'),
      isEmpty,
    );
  });

  test('search filters come from category metadata without a section switch', () {
    const pavilion = CategoryConfiguration(
      id: 'new',
      slug: 'floating_pavilion',
      name: 'Floating Pavilion',
      sectionId: 'function_halls',
      searchable: true,
      filters: ['gender', 'price_range'],
      amenities: ['wifi', 'parking'],
    );
    final specs = CategoryFilterCatalog.specs(
      const [pavilion],
      sectionId: 'function_halls',
      fallback: CustomerSectionCatalog.filterSpecs(
        CustomerSection.functionHalls,
      ),
    );
    expect(specs.map((s) => s.field), [
      SectionFilterField.gender,
      SectionFilterField.priceRange,
    ]);
    expect(
      specs.map((s) => s.field),
      isNot(contains(SectionFilterField.date)),
    );
    final amenities = CategoryFilterCatalog.amenities(
      const [pavilion],
      sectionId: 'function_halls',
      fallback: CustomerSectionCatalog.amenityFilters(
        CustomerSection.functionHalls,
      ),
    );
    expect(amenities.map((a) => a.id), ['wifi', 'parking']);
  });

  test('search filters fall back when category metadata has none', () {
    const hall = CategoryConfiguration(
      id: 'h',
      slug: 'marriage_hall',
      name: 'Marriage Hall',
      sectionId: 'function_halls',
      searchable: true,
    );
    final specs = CategoryFilterCatalog.specs(
      const [hall],
      sectionId: 'function_halls',
      fallback: CustomerSectionCatalog.filterSpecs(
        CustomerSection.functionHalls,
      ),
    );
    expect(specs.map((s) => s.field), contains(SectionFilterField.date));
  });

  test('search filter categories stay bounded and ordered', () {
    final items = [
      for (var i = 0; i < 120; i++)
        CategoryConfiguration(
          id: '$i',
          slug: 'cat_$i',
          name: 'Cat $i',
          sectionId: 'function_halls',
          sortOrder: 120 - i,
        ),
    ];
    final chips = CategoryDiscovery.searchFilterCategories(
      items,
      sectionId: 'function_halls',
    );
    expect(chips.length, lessThanOrEqualTo(CategoryDiscovery.maxQuery));
    expect(chips.first.slug, 'cat_119');
  });

  test('search chips keep unknown database categories without a new enum', () {
    final pavilion = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: 'new',
        slug: 'floating_pavilion',
        name: 'Floating Pavilion',
        metadata: {
          'section': 'function_halls',
          'searchable': true,
          'home_visible': true,
        },
      ),
    );
    expect(pavilion.slug, 'floating_pavilion');
    expect(
      CategoryDiscovery.searchChips([
        pavilion,
      ], sectionId: 'function_halls').map((c) => c.slug),
      ['floating_pavilion'],
    );
  });

  test(
    'search chips fall back to the current catalog when config is empty',
    () {
      const fallback = [
        CategoryConfiguration(
          id: 'marriage_hall',
          slug: 'marriage_hall',
          name: 'Marriage Hall',
          sectionId: 'function_halls',
        ),
      ];
      expect(
        CategoryDiscovery.searchChips(
          const [],
          sectionId: 'function_halls',
          fallback: fallback,
        ).map((c) => c.slug),
        ['marriage_hall'],
      );
    },
  );

  test('disabled search section does not appear in search chips', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.pg, enabled: false);
    expect(registry.visibleSearchSections(), isNot(contains('pg_hostels')));
    expect(registry.visibleSearchSections(), contains('function_halls'));
  });

  test('registration defaults stay off so current booking is unchanged', () {
    const hall = CategoryConfiguration(
      id: 'h',
      slug: 'function_hall',
      name: 'Hall',
    );
    final registration = CategoryRegistrationConfig.from(hall);
    expect(registration.enabled, isFalse);
    expect(registration.kycRequired, isFalse);
    expect(registration.requiredFields, isEmpty);
    expect(registration.enforcedForBooking, isFalse);
    expect(registration.missing(const {}), isEmpty);
  });

  test('registration ON/OFF and fields are metadata-driven per category', () {
    final campus = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: 'c1',
        slug: 'robotics_lab',
        name: 'Robotics Lab',
        metadata: {
          'registration_required': true,
          'kyc_required': true,
          'registration_required_fields': ['student_name', 'guardian_phone'],
          'registration_optional_fields': ['notes'],
        },
      ),
    );
    final registration = CategoryRegistrationConfig.from(campus);
    expect(registration.enabled, isTrue);
    expect(registration.kycRequired, isTrue);
    expect(registration.requiredFields, ['student_name', 'guardian_phone']);
    expect(registration.optionalFields, ['notes']);
    expect(registration.enforcedForBooking, isTrue);
    expect(
      registration.missing({'student_name': 'Asha'}),
      containsAll(['guardian_phone', 'kyc_document']),
    );
    expect(
      registration.missing({
        'student_name': 'Asha',
        'guardian_phone': '9876543210',
        'kyc_document': 'aadhaar.pdf',
      }),
      isEmpty,
    );
  });

  test(
    'booking does not enforce registration when the category has it off',
    () {
      const hotel = CategoryConfiguration(
        id: 'h',
        slug: 'boutique_stay',
        name: 'Boutique Stay',
        registrationRequired: false,
        kycRequired: true,
        registrationRequiredFields: ['id_proof'],
      );
      final registration = CategoryRegistrationConfig.from(hotel);
      expect(registration.enforcedForBooking, isFalse);
      expect(registration.missing(const {}), isEmpty);
    },
  );

  test(
    'booking validation uses category required fields instead of only date/guests',
    () {
      const hotel = CategoryConfiguration(
        id: 'o',
        slug: 'boutique_stay',
        name: 'Boutique Stay',
        bookingRequiredFields: ['check_in', 'check_out'],
        bookingOptionalFields: ['guests'],
      );
      final specs = ConfigurableBookingFields.from(hotel);
      final intent = const BookingIntentParser().parse('book a hotel');
      expect(intent.wantsBooking, isTrue);
      expect(
        intent.missingRequiredFor(specs),
        containsAll(['check_in', 'check_out']),
      );
      expect(intent.missingRequiredFor(specs), isNot(contains('guests')));
      expect(intent.isCompleteForBookingWith(specs), isFalse);
    },
  );

  test('each category can enable registration independently', () {
    const hall = CategoryConfiguration(
      id: 'h',
      slug: 'function_hall',
      name: 'Hall',
      registrationRequired: false,
    );
    const event = CategoryConfiguration(
      id: 'e',
      slug: 'night_market',
      name: 'Night Market',
      registrationRequired: true,
      kycRequired: true,
      registrationRequiredFields: ['attendee_name'],
      bookingRequiredFields: ['ticket_quantity'],
    );
    expect(CategoryRegistrationConfig.from(hall).enforcedForBooking, isFalse);
    final eventReg = CategoryRegistrationConfig.from(event);
    expect(eventReg.enforcedForBooking, isTrue);
    expect(
      eventReg.missing(const {}),
      containsAll(['attendee_name', 'kyc_document']),
    );
    expect(ConfigurableBookingFields.from(event).map((f) => f.key), [
      'ticket_quantity',
    ]);
  });

  test('unified registration lists a DB category without a Dart enum', () {
    const pavilion = CategoryConfiguration(
      id: 'new',
      slug: 'floating_pavilion',
      name: 'Floating Pavilion',
      registrationRequired: true,
      kycRequired: true,
    );
    final modules = UnifiedRegistrationModule.resolve(const [pavilion]);
    expect(
      modules.map((m) => m.key),
      contains('floating_pavilion'),
    );
    expect(FeatureId.values.map((id) => id.name), isNot(contains('floatingPavilion')));
    expect(
      UnifiedRegistrationModule.resolve(const []).map((m) => m.key),
      ['customer', 'venue_owner', 'institute_student', 'event_attendee'],
    );
  });

  test('invoice and QR follow category visibility without a second engine', () {
    const hidden = CategoryConfiguration(
      id: 'h',
      slug: 'secret_hall',
      name: 'Secret Hall',
      invoiceVisible: false,
      notificationVisible: false,
      qrVisible: false,
    );
    final display = InvoiceDisplayConfig.fromFeature(
      const FeatureConfig(enabled: true),
    ).applyCategory(hidden);
    expect(display.showPdf, isFalse);
    expect(display.showShare, isFalse);
    expect(display.showNotificationStatus, isFalse);
    expect(display.showQr, isFalse);
  });

  test('booking validation defaults keep asking for date and guests', () {
    final intent = const BookingIntentParser().parse('book a function hall');
    expect(intent.missingRequired, containsAll(['date', 'guests']));
    expect(intent.isCompleteForBooking, isFalse);
  });
}
