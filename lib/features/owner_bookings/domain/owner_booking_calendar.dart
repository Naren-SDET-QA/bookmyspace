import '../../booking/domain/booking.dart';

/// Groups owner bookings by calendar day using server booking dates.
class OwnerBookingCalendar {
  const OwnerBookingCalendar._();

  static DateTime dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static Map<DateTime, List<Booking>> groupByDate(List<Booking> bookings) {
    final grouped = <DateTime, List<Booking>>{};
    for (final booking in bookings) {
      grouped.putIfAbsent(dayKey(booking.bookDate), () => []).add(booking);
    }
    return grouped;
  }

  static int confirmedCount(List<Booking> bookings) {
    return bookings
        .where(
          (b) =>
              b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.completed,
        )
        .length;
  }
}
