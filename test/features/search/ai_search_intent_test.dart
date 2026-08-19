import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/location/domain/search_area.dart';
import 'package:bookmyspace/features/search/domain/ai_search_intent.dart';

void main() {
  test('parses section, category, city, date, guests, budget and booking intent', () {
    final intent = AiSearchIntent.parse(
      'book marriage hall in Hyderabad on 2026-12-25 for 500 guests under 50000',
    );
    expect(intent.section, CustomerSection.functionHalls);
    expect(intent.categorySlug, 'marriage_hall');
    expect(intent.city, 'hyderabad');
    expect(intent.date, DateTime(2026, 12, 25));
    expect(intent.guests, 500);
    expect(intent.maxPrice, 50000);
    expect(intent.bookingIntent, isTrue);
  });

  test('selected section wins and invalid cross-section category is rejected', () {
    final intent = AiSearchIntent.parse(
      'find a marriage hall near Bengaluru',
      selectedSection: CustomerSection.pgHostels,
    );
    final query = intent.toQuery(
      selectedSection: CustomerSection.pgHostels,
      area: SearchArea.defaultArea,
    );
    expect(query.sectionId, CustomerSection.pgHostels.id);
    expect(query.categorySlug, isNull);
  });

  test('institutes remain non-bookable in interpreted search context', () {
    final intent = AiSearchIntent.parse('book coaching class in Hyderabad');
    expect(intent.section, CustomerSection.institutesClasses);
    expect(intent.bookingIntent, isTrue);
    expect(CustomerSection.institutesClasses.isBookable, isFalse);
  });
}
