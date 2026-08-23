import 'event.dart';

enum EventPriceFilter { all, free, paid }

/// Client-side discovery filter over published event rows from Supabase.
/// Does not invent events or change registration state.
class EventDiscoveryQuery {
  const EventDiscoveryQuery({
    this.query = '',
    this.category,
    this.price = EventPriceFilter.all,
  });

  final String query;
  final EventCategory? category;
  final EventPriceFilter price;

  List<Event> apply(List<Event> events) {
    final needle = query.trim().toLowerCase();
    return events.where((event) {
      if (category != null && event.category != category) return false;
      if (price == EventPriceFilter.free && !_isFree(event)) return false;
      if (price == EventPriceFilter.paid && _isFree(event)) return false;
      if (needle.isEmpty) return true;
      return [
        event.title,
        event.description,
        event.venueName,
        event.category.dbValue,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList();
  }

  bool _isFree(Event event) => event.isFree || event.ticketPrice <= 0;
}
