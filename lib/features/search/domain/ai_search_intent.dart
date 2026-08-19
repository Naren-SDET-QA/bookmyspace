import '../../home/domain/customer_section_catalog.dart';
import '../../location/domain/search_area.dart';
import '../../venues/domain/venue.dart';

/// A conservative, local interpretation of natural-language search. It only
/// builds a normal [VenueSearchQuery]; the repository and booking flow remain
/// authoritative for listings, price and availability.
class AiSearchIntent {
  const AiSearchIntent({
    required this.query,
    required this.section,
    this.categorySlug,
    this.city,
    this.date,
    this.guests,
    this.maxPrice,
    this.bookingIntent = false,
  });

  final String query;
  final CustomerSection? section;
  final String? categorySlug;
  final String? city;
  final DateTime? date;
  final int? guests;
  final double? maxPrice;
  final bool bookingIntent;

  VenueSearchQuery toQuery({
    required CustomerSection selectedSection,
    required SearchArea area,
  }) {
    final scoped = section == null || section == selectedSection
        ? selectedSection
        : selectedSection;
    final category = categorySlug != null &&
            scoped.categories.any((item) => item.id == categorySlug)
        ? categorySlug
        : null;
    final isStay = scoped == CustomerSection.lodgeRooms ||
        scoped == CustomerSection.pgHostels;
    return VenueSearchQuery(
      query: query,
      sectionId: scoped.id,
      categorySlug: category,
      city: city,
      maxPrice: maxPrice,
      minCapacity: scoped == CustomerSection.functionHalls ? guests : null,
      date: scoped == CustomerSection.functionHalls ? date : null,
      checkIn: isStay ? date : null,
      latitude: area.latitude,
      longitude: area.longitude,
      maxDistanceKm: area.radiusKm,
    );
  }

  static AiSearchIntent parse(
    String utterance, {
    CustomerSection? selectedSection,
  }) {
    final text = utterance.trim().toLowerCase();
    final section = selectedSection ?? _section(text);
    final category = section == null ? null : _category(text, section);
    final city = _city(text);
    final date = _date(text);
    final guests = int.tryParse(
      RegExp(r'(\d+)\s*(?:guests?|people|persons?)').firstMatch(text)?.group(1) ?? '',
    );
    final maxPrice = double.tryParse(
      (RegExp(r'(?:under|below|upto|up to|max(?:imum)?)\s*[₹rs.]?\s*([\d,]+)')
                  .firstMatch(text)
                  ?.group(1) ??
              '')
          .replaceAll(',', ''),
    );
    return AiSearchIntent(
      query: utterance.trim(),
      section: section,
      categorySlug: category,
      city: city,
      date: date,
      guests: guests,
      maxPrice: maxPrice,
      bookingIntent: text.contains('book') || text.contains('reserve'),
    );
  }

  static CustomerSection? _section(String text) {
    if (text.contains('hall') || text.contains('marriage') || text.contains('banquet')) {
      return CustomerSection.functionHalls;
    }
    if (text.contains('lodge') || text.contains('hotel') || text.contains('room')) {
      return CustomerSection.lodgeRooms;
    }
    if (text.contains('pg') || text.contains('hostel') || text.contains('co-liv')) {
      return CustomerSection.pgHostels;
    }
    if (text.contains('institute') || text.contains('class') || text.contains('coaching')) {
      return CustomerSection.institutesClasses;
    }
    return null;
  }

  static String? _category(String text, CustomerSection section) {
    for (final category in section.categories.skip(1)) {
      final words = category.label.toLowerCase().split(RegExp(r'[^a-z]+'));
      if (words.any((word) => word.length > 3 && text.contains(word))) {
        return category.id;
      }
    }
    return null;
  }

  static String? _city(String text) {
    final match = RegExp(r'\b(?:in|near|at)\s+([a-z]+)').firstMatch(text);
    return match?.group(1);
  }

  static DateTime? _date(String text) {
    final match = RegExp(r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(text);
    if (match == null) return null;
    return DateTime.tryParse('${match.group(1)}-${match.group(2)!.padLeft(2, '0')}-${match.group(3)!.padLeft(2, '0')}');
  }
}
