import 'package:intl/intl.dart';

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
  });
  final String? category;
  final String? location;
  final DateTime? date;
  final int? nights;
  final int? guests;
  final double? budget;
  final List<String> amenities;

  bool get hasSearchSignal =>
      category != null || location != null || budget != null || guests != null;
  String get dateLabel => date == null ? '' : DateFormat.yMMMd().format(date!);
}

class BookingIntentParser {
  const BookingIntentParser();

  BookingIntent parse(String input, {DateTime? now}) {
    final text = input.trim();
    final lower = text.toLowerCase();
    final reference = now ?? DateTime.now();
    String? category;
    if (RegExp(r'function\s*hall|hall').hasMatch(lower))
      category = 'function_halls';
    if (RegExp(r'pg|hostel').hasMatch(lower)) category = 'pg_hostels';
    if (RegExp(r'hotel|room|lodge').hasMatch(lower)) category = 'lodge_rooms';
    if (RegExp(r'meeting|conference').hasMatch(lower))
      category = 'meeting_spaces';
    final locationMatch = RegExp(
      r'\b(?:in|near|at)\s+([A-Za-z][A-Za-z .-]{2,})',
      caseSensitive: false,
    ).firstMatch(text);
    final location = locationMatch
        ?.group(1)
        ?.replaceAll(
          RegExp(r'\s+(?:for|under|on)\s+.*$', caseSensitive: false),
          '',
        )
        .trim();
    final guests = int.tryParse(
      RegExp(
            r'(\d[\d,]*)\s*(?:people|guests|persons|occupancy)',
            caseSensitive: false,
          ).firstMatch(text)?.group(1)?.replaceAll(',', '') ??
          '',
    );
    final budgetMatch = RegExp(
      r'(?:under|below|budget\s*(?:of|is)?)\s*[₹$]?\s*([\d,]+)',
      caseSensitive: false,
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
    if (lower.contains('tomorrow'))
      date = DateTime(reference.year, reference.month, reference.day + 1);
    else if (lower.contains('today'))
      date = DateTime(reference.year, reference.month, reference.day);
    else if (lower.contains('sunday')) {
      final days = (DateTime.sunday - reference.weekday + 7) % 7;
      date = DateTime(
        reference.year,
        reference.month,
        reference.day + (days == 0 ? 7 : days),
      );
    }
    return BookingIntent(
      category: category,
      location: location,
      date: date,
      nights: nights,
      guests: guests,
      budget: budget,
    );
  }
}
