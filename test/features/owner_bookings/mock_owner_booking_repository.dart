import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';

/// In-memory owner booking repository for tests.
class MockOwnerBookingRepository implements OwnerBookingRepository {
  MockOwnerBookingRepository({List<Booking>? bookings})
    : _bookings = bookings ?? [];

  final List<Booking> _bookings;

  bool failCreateOffline = false;
  bool failUpdateStatus = false;
  Booking? lastCreated;
  String? lastUpdatedBookingId;
  OwnerBookingAction? lastAction;

  @override
  Future<List<Booking>> myVenueBookings() async => List.of(_bookings);

  @override
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) async {
    if (failCreateOffline) throw Exception('create failed');
    final booking = Booking(
      id: 'off-1',
      bookingRef: 'BMS-OFF01',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: '09:00:00',
      endTime: '13:00:00',
      status: BookingStatus.confirmed,
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      venueName: 'Sunrise Function Hall',
      customerName: customerName,
      customerPhone: customerPhone,
      isOffline: true,
      paymentMethod: 'offline',
    );
    lastCreated = booking;
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<Booking> updateStatus(
    String bookingId,
    OwnerBookingAction action,
  ) async {
    if (failUpdateStatus) throw Exception('update failed');
    lastUpdatedBookingId = bookingId;
    lastAction = action;
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index < 0) throw Exception('Booking not found: $bookingId');
    final next = switch (action) {
      OwnerBookingAction.confirm => BookingStatus.confirmed,
      OwnerBookingAction.complete => BookingStatus.completed,
      OwnerBookingAction.cancel => BookingStatus.cancelled,
      OwnerBookingAction.noShow => BookingStatus.noShow,
    };
    final current = _bookings[index];
    _bookings[index] = Booking(
      id: current.id,
      bookingRef: current.bookingRef,
      venueId: current.venueId,
      slotId: current.slotId,
      bookDate: current.bookDate,
      startTime: current.startTime,
      endTime: current.endTime,
      status: next,
      amount: current.amount,
      taxAmount: current.taxAmount,
      totalAmount: current.totalAmount,
      venueName: current.venueName,
      venueCity: current.venueCity,
      slotLabel: current.slotLabel,
      customerName: current.customerName,
      customerPhone: current.customerPhone,
      isOffline: current.isOffline,
      paymentMethod: current.paymentMethod,
      paymentRef: current.paymentRef,
      paidAt: current.paidAt,
      metadata: current.metadata,
    );
    return _bookings[index];
  }
}