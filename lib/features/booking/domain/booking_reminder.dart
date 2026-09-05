import 'booking.dart';

/// A local pre-session reminder, matching the legacy Android 1-hour alert.
class BookingReminder {
  const BookingReminder({
    required this.bookingId,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.immediate,
  });

  final String bookingId;
  final DateTime fireAt;
  final String title;
  final String body;
  final bool immediate;

  int get notificationId => bookingId.hashCode & 0x7fffffff;
}

/// Pure planner: which confirmed bookings should fire a 1-hour reminder.
///
/// Email / FCM outbox notifications are unchanged. This only describes local
/// device alerts so they can be scheduled where the OS allows it.
class BookingReminderPlanner {
  const BookingReminderPlanner({this.lead = const Duration(hours: 1)});

  final Duration lead;

  static DateTime? sessionStart(Booking booking) {
    final parts = booking.startTime.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(
      booking.bookDate.year,
      booking.bookDate.month,
      booking.bookDate.day,
      hour,
      minute,
    );
  }

  List<BookingReminder> plan(List<Booking> bookings, DateTime now) {
    final reminders = <BookingReminder>[];
    for (final booking in bookings) {
      if (booking.status != BookingStatus.confirmed) continue;
      final start = sessionStart(booking);
      if (start == null || !start.isAfter(now)) continue;
      var fireAt = start.subtract(lead);
      var immediate = false;
      if (!fireAt.isAfter(now)) {
        fireAt = now;
        immediate = true;
      }
      final venue = booking.venueName.isEmpty ? 'your booking' : booking.venueName;
      reminders.add(
        BookingReminder(
          bookingId: booking.id,
          fireAt: fireAt,
          title: 'Session starts in 1 hour',
          body: '$venue · ${booking.displayStart}–${booking.displayEnd}',
          immediate: immediate,
        ),
      );
    }
    return List.unmodifiable(reminders);
  }
}
