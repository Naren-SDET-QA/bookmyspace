import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/booking_reminder.dart';
import 'package:bookmyspace/features/booking/domain/booking_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _booking({
  required String id,
  required BookingStatus status,
  required DateTime date,
  String start = '18:00:00',
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-$id',
    venueId: 'v1',
    slotId: 's1',
    bookDate: date,
    startTime: start,
    endTime: '19:00:00',
    status: status,
    amount: 100,
    taxAmount: 18,
    totalAmount: 118,
    venueName: 'Sunrise Hall',
  );
}

class _RecordingGateway implements LocalReminderGateway {
  final shown = <int>[];
  final scheduled = <int>[];
  final cancelled = <int>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async => shown.add(id);

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => scheduled.add(id);
}

void main() {
  final now = DateTime(2026, 9, 1, 12, 0);

  test('plans a 1-hour reminder for confirmed upcoming sessions', () {
    final bookings = [
      _booking(
        id: 'soon',
        status: BookingStatus.confirmed,
        date: DateTime(2026, 9, 1),
        start: '13:30:00',
      ),
      _booking(
        id: 'pending',
        status: BookingStatus.pending,
        date: DateTime(2026, 9, 1),
        start: '13:30:00',
      ),
      _booking(
        id: 'past',
        status: BookingStatus.confirmed,
        date: DateTime(2026, 8, 1),
      ),
    ];
    final planned = const BookingReminderPlanner().plan(bookings, now);
    expect(planned, hasLength(1));
    expect(planned.single.bookingId, 'soon');
    expect(planned.single.fireAt, DateTime(2026, 9, 1, 12, 30));
    expect(planned.single.immediate, isFalse);
  });

  test('marks reminders immediate when the session is already inside the lead window', () {
    final bookings = [
      _booking(
        id: 'now',
        status: BookingStatus.confirmed,
        date: DateTime(2026, 9, 1),
        start: '12:30:00',
      ),
    ];
    final planned = const BookingReminderPlanner().plan(bookings, now);
    expect(planned.single.immediate, isTrue);
    expect(planned.single.fireAt, now);
  });

  test('scheduler posts immediate reminders and skips unsupported platforms', () async {
    final gateway = _RecordingGateway();
    final supported = BookingReminderScheduler(gateway: gateway);
    final unsupported = BookingReminderScheduler(
      gateway: gateway,
      supported: false,
    );
    final bookings = [
      _booking(
        id: 'now',
        status: BookingStatus.confirmed,
        date: DateTime(2026, 9, 1),
        start: '12:30:00',
      ),
    ];
    await unsupported.sync(bookings, now: now);
    expect(gateway.shown, isEmpty);
    await supported.sync(bookings, now: now);
    expect(gateway.shown, isNotEmpty);
  });
}
