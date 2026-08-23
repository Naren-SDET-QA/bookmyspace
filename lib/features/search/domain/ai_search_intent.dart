import '../../home/domain/customer_section_catalog.dart';
import '../../location/domain/search_area.dart';
import '../../venues/domain/category_configuration.dart';
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
    CategoryAliasIndex? aliases,
    DateTime? now,
  }) {
    final text = utterance.trim().toLowerCase();
    final matched = aliases?.match(utterance);
    final section = selectedSection ??
        CustomerSection.fromId(matched?.sectionId) ??
        _section(text);
    final category = matched?.slug ??
        (section == null ? null : _category(text, section));
    return AiSearchIntent(
      query: utterance.trim(),
      section: section,
      categorySlug: category,
      city: _city(utterance),
      date: _date(text, now ?? DateTime.now()),
      guests: _guests(text),
      maxPrice: _maxPrice(text),
      bookingIntent: _bookingIntent(text),
    );
  }

  static CustomerSection? _section(String text) {
    if (_containsAny(text, const [
      'hall',
      'marriage',
      'banquet',
      'mandap',
      'హాల్',
      'మ్యారేజ్',
      'మండపం',
      'కళ్యాణ',
      'हॉल',
      'मैरिज',
      'बैंक्वेट',
      'मंडप',
    ])) {
      return CustomerSection.functionHalls;
    }
    if (_containsAny(text, const [
      'lodge',
      'hotel',
      'room',
      'stay',
      'హోటల్',
      'లాడ్జ్',
      'రూమ్',
      'होटल',
      'लॉज',
      'रूम',
      'कमरा',
    ])) {
      return CustomerSection.lodgeRooms;
    }
    if (_containsAny(text, const [
      'pg',
      'hostel',
      'co-liv',
      'coliv',
      'పీజీ',
      'హాస్టల్',
      'पीजी',
      'हॉस्टल',
    ])) {
      return CustomerSection.pgHostels;
    }
    if (_containsAny(text, const [
      'institute',
      'class',
      'coaching',
      'course',
      'ఇన్స్టిట్యూట్',
      'క్లాస్',
      'కోచింగ్',
      'इंस्टिट्यूट',
      'क्लास',
      'कोचिंग',
    ])) {
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

  static String? _city(String utterance) {
    final match = RegExp(
      r'(?:in|near|at|లో|దగ్గర|में|के पास)\s+([^\s,]+)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(utterance.trim());
    final city = match?.group(1)?.trim();
    if (city == null || city.isEmpty) return null;
    return city.toLowerCase();
  }

  static DateTime? _date(String text, DateTime now) {
    final iso = RegExp(r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(text);
    if (iso != null) {
      return DateTime.tryParse(
        '${iso.group(1)}-${iso.group(2)!.padLeft(2, '0')}-${iso.group(3)!.padLeft(2, '0')}',
      );
    }
    if (_containsAny(text, const ['tomorrow', 'రేపు', 'कल'])) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (_containsAny(text, const ['today', 'ఈరోజు', 'आज'])) {
      return DateTime(now.year, now.month, now.day);
    }
    return null;
  }

  static int? _guests(String text) {
    return int.tryParse(
      RegExp(
            r'(\d+)\s*(?:guests?|people|persons?|మంది|అతిథులు|लोग|मेहमान|अतिथि)',
            unicode: true,
          ).firstMatch(text)?.group(1) ??
          '',
    );
  }

  static double? _maxPrice(String text) {
    return double.tryParse(
      (RegExp(
                    r'(?:under|below|upto|up to|max(?:imum)?|కింద|లోపల|से कम|तक)\s*[₹rs.]?\s*([\d,]+)',
                    unicode: true,
                  )
                  .firstMatch(text)
                  ?.group(1) ??
              '')
          .replaceAll(',', ''),
    );
  }

  static bool _bookingIntent(String text) {
    return _containsAny(text, const [
      'book',
      'reserve',
      'బుక్',
      'రిజర్వ్',
      'बुक',
      'आरक्षित',
    ]);
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (needle.isNotEmpty && text.contains(needle.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
