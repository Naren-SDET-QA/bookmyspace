import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import '../infrastructure/supabase_booking_repository.dart';
import '../infrastructure/caching_booking_repository.dart';
import '../../../core/offline/offline_providers.dart';
import '../domain/invoice_repository.dart';
import '../infrastructure/supabase_invoice_repository.dart';

/// Booking repository instance.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return CachingBookingRepository(
    SupabaseBookingRepository(client),
    ref.watch(offlineCacheProvider),
    cacheScope: ref.watch(currentUserProvider)?.id,
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return SupabaseInvoiceRepository(ref.watch(supabaseProvider));
});

final invoiceArtifactProvider = FutureProvider.autoDispose
    .family<InvoiceArtifact, String>((ref, bookingId) {
      return ref.watch(invoiceRepositoryProvider).generate(bookingId);
    });

/// Availability of the venue's slots for a given (venueId, date) pair.
final slotAvailabilityProvider = FutureProvider.autoDispose
    .family<List<SlotAvailability>, SlotAvailabilityQuery>((ref, query) {
      return ref
          .watch(bookingRepositoryProvider)
          .availableTimeSlots(venueId: query.venueId, date: query.date);
    });

/// The signed-in user's bookings, newest first.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.watch(bookingRepositoryProvider).myBookings();
  try {
    await ref.read(bookingReminderSchedulerProvider).sync(bookings);
  } catch (_) {
    // Local reminders must never block the bookings list or email outbox.
  }
  return bookings;
});

/// A single booking by id (used by the invoice screen).
final bookingByIdProvider = FutureProvider.autoDispose.family<Booking, String>((
  ref,
  bookingId,
) {
  return ref.watch(bookingRepositoryProvider).bookingById(bookingId);
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
