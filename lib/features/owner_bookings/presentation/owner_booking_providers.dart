import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../domain/owner_booking_repository.dart';
import '../infrastructure/supabase_owner_booking_repository.dart';

/// Owner booking repository instance.
final ownerBookingRepositoryProvider = Provider<OwnerBookingRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseOwnerBookingRepository(client);
});

/// Bookings across the signed-in owner's venues.
final ownerBookingsProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(ownerBookingRepositoryProvider).myVenueBookings();
});