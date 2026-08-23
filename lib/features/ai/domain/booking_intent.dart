import 'package:intl/intl.dart';

import '../../booking/domain/configurable_booking.dart';

/// Provider-neutral intent extracted from typed or spoken customer input.
class BookingIntent {
  const BookingIntent({
    this.category,
    this.location,
    this.date,
    this.nights,
    this.guests,
    this.budget,
    this.amenities = const [],
    this.wantsBooking = false,
  });
  final String? category;
  final String? location;
  final DateTime? date;
  final int? nights;
  final int? guests;
  final double? budget;
  final List<String> amenities;
  final bool wantsBooking;

  bool get hasSearchSignal =>
      category != null || location != null || budget != null || guests != null;
  String get dateLabel => date == null ? '' : DateFormat.yMMMd().format(date!);

  List<String> get missingRequired => missingRequiredFor(const [
    BookingFieldSpec(key: 'date'),
    BookingFieldSpec(key: 'guests'),
  ]);

  List<String> missingRequiredFor(List<BookingFieldSpec> fields) {
    final missing = <String>[];
    if (category == null) missing.add('category');
    if (wantsBooking) {
      missing.addAll(toFieldValues().missing(fields));
    }
    return missing;
  }

  bool get isCompleteForBooking => wantsBooking && missingRequired.isEmpty;

  bool isCompleteForBookingWith(List<BookingFieldSpec> fields) =>
      wantsBooking && missingRequiredFor(fields).isEmpty;

  BookingFieldValues toFieldValues() => BookingFieldValues({
    if (date != null) 'date': date,
    if (guests != null) 'guests': guests,
    if (nights != null) 'duration': nights,
  });
}

class BookingIntentParser {
  const BookingIntentParser();

  BookingIntent parse(String input, {DateTime? now}) {
    final text = input.trim();
    final lower = text.toLowerCase();
    final reference = now ?? DateTime.now();
    String? category;
    if (RegExp(
      r'function\s*hall|hall|mandap|ఫంక్షన్|హాల్|మండపం|हॉल|मंडप',
      unicode: true,
    ).hasMatch(lower)) {
      category = 'function_halls';
    }
    if (RegExp(
      r'pg|hostel|పీజీ|హాస్టల్|पीजी|हॉस्टल',
      unicode: true,
    ).hasMatch(lower)) {
      category = 'pg_hostels';
    }
    if (RegExp(
      r'hotel|room|lodge|హోటల్|లాడ్జ్|होटल|कमरा|लॉज',
      unicode: true,
    ).hasMatch(lower)) {
      category = 'lodge_rooms';
    }
    if (RegExp(r'meeting|conference').hasMatch(lower)) {
      category = 'meeting_spaces';
    }
    final locationMatch = RegExp(
      r'(?:in|near|at|లో|దగ్గర|में|के पास)\s+([^\s,]+)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final location = locationMatch?.group(1)?.trim();
    final guests = int.tryParse(
      RegExp(
            r'(\d[\d,]*)\s*(?:people|guests|persons|occupancy|మంది|अतिथि|लोग|मेहमान)',
            caseSensitive: false,
            unicode: true,
          ).firstMatch(text)?.group(1)?.replaceAll(',', '') ??
          '',
    );
    final budgetMatch = RegExp(
      r'(?:under|below|budget\s*(?:of|is)?|కింద|లోపల|से कम|तक)\s*[₹$]?\s*([\d,]+)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final budget = double.tryParse(
      budgetMatch?.group(1)?.replaceAll(',', '') ?? '',
    );
    final nights = int.tryParse(
      RegExp(
            r'(\d+)\s*nights?',
            caseSensitive: false,
          ).firstMatch(text)?.group(1) ??
          '',
    );
    DateTime? date;
    if (lower.contains('tomorrow') ||
        lower.contains('రేపు') ||
        lower.contains('कल')) {
      date = DateTime(reference.year, reference.month, reference.day + 1);
    } else if (lower.contains('today') ||
        lower.contains('ఈరోజు') ||
        lower.contains('आज')) {
      date = DateTime(reference.year, reference.month, reference.day);
    } else if (lower.contains('sunday')) {
      final days = (DateTime.sunday - reference.weekday + 7) % 7;
      date = DateTime(
        reference.year,
        reference.month,
        reference.day + (days == 0 ? 7 : days),
      );
    }
    final wantsBooking = RegExp(
      r'book|booking|reserve|బుక్|बुक',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(text);
    return BookingIntent(
      category: category,
      location: location,
      date: date,
      nights: nights,
      guests: guests,
      budget: budget,
      wantsBooking: wantsBooking,
    );
  }
}
