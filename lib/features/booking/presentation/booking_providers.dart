import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import '../infrastructure/supabase_booking_repository.dart';

/// Booking repository instance.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseBookingRepository(client);
});

/// Availability of the venue's slots for a given (venueId, date) pair.
final slotAvailabilityProvider = FutureProvider.autoDispose
    .family<List<SlotAvailability>, SlotAvailabilityQuery>((ref, query) {
      return ref
          .watch(bookingRepositoryProvider)
          .availableTimeSlots(venueId: query.venueId, date: query.date);
    });

/// The signed-in user's bookings, newest first.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).myBookings();
});

/// The currently selected booking date (reset per screen visit).
final selectedBookingDateProvider = StateProvider<DateTime?>((ref) => null);

/// The currently selected slot availability (reset per screen visit).
final selectedSlotProvider = StateProvider<SlotAvailability?>((ref) => null);

/// Key for the slot availability family.
class SlotAvailabilityQuery {
  const SlotAvailabilityQuery({required this.venueId, required this.date});

  final String venueId;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is SlotAvailabilityQuery &&
      other.venueId == venueId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(venueId, date);
}
