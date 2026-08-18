import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

void main() {
  test('catalog has exactly four customer sections', () {
    expect(CustomerSection.values, hasLength(4));
    expect(
      CustomerSection.values.map((s) => s.id).toList(),
      ['function_halls', 'lodge_rooms', 'pg_hostels', 'institutes_classes'],
    );
  });

  test('halls do not include lodge, pg or coworking', () {
    final halls = MockVenueRepository.defaultVenues
        .where(
          (v) => CustomerSectionCatalog.matchesVenue(
            v,
            CustomerSection.functionHalls,
          ),
        )
        .toList();
    expect(halls.map((v) => v.name), contains('Sunrise Function Hall'));
    expect(halls.any((v) => v.name.contains('Ladies PG')), isFalse);
    expect(halls.any((v) => v.name.contains('Crown Lodge')), isFalse);
    expect(halls.any((v) => v.name.contains('Work Nest')), isFalse);
  });

  test('pg ladies category stays ladies-only', () {
    final ladies = MockVenueRepository.defaultVenues.where(
      (v) => CustomerSectionCatalog.matchesVenue(
        v,
        CustomerSection.pgHostels,
        'ladies_pg',
      ),
    );
    expect(ladies, isNotEmpty);
    expect(ladies.every((v) => v.name.toLowerCase().contains('ladies')), isTrue);
  });

  test('institutes are listings and not bookable', () {
    expect(CustomerSection.institutesClasses.isBookable, isFalse);
    expect(
      CustomerSectionCatalog.bookingCtaLabel(
        CustomerSection.institutesClasses,
      ),
      'Enquire',
    );
  });

  test('owner contact stays hidden until paid booking except institutes', () {
    expect(
      CustomerSectionCatalog.canRevealOwnerContact(
        section: CustomerSection.functionHalls,
        hasConfirmedPaidBooking: false,
      ),
      isFalse,
    );
    expect(
      CustomerSectionCatalog.canRevealOwnerContact(
        section: CustomerSection.functionHalls,
        hasConfirmedPaidBooking: true,
      ),
      isTrue,
    );
    expect(
      CustomerSectionCatalog.canRevealOwnerContact(
        section: CustomerSection.institutesClasses,
        hasConfirmedPaidBooking: false,
      ),
      isTrue,
    );
  });

  test('required customer fields stay section-specific', () {
    expect(
      CustomerSectionCatalog.requiredCustomerFields(
        CustomerSection.functionHalls,
      ),
      containsAll([
        CustomerDetailField.fullName,
        CustomerDetailField.phone,
        CustomerDetailField.eventType,
      ]),
    );
    expect(
      CustomerSectionCatalog.requiredCustomerFields(
        CustomerSection.pgHostels,
      ),
      contains(CustomerDetailField.idNumber),
    );
    expect(
      CustomerSectionCatalog.requiredCustomerFields(
        CustomerSection.institutesClasses,
      ),
      isEmpty,
    );
  });

  test('unknown slugs are excluded from all four sections', () {
    const coworking = Venue(
      id: 'x',
      name: 'The Work Nest',
      latitude: 0,
      longitude: 0,
      category: VenueCategory(
        id: 'c',
        slug: 'coworking_space',
        name: 'Coworking',
      ),
    );
    expect(CustomerSectionCatalog.sectionForVenue(coworking), isNull);
  });
}
