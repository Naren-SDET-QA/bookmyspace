import 'package:bookmyspace/features/owner_bookings/infrastructure/supabase_owner_booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline booking retry key is stable for the same request', () {
    final first = SupabaseOwnerBookingRepository.offlineIdempotencyKey(
      venueId: 'venue-1',
      slotId: 'slot-1',
      bookDate: DateTime(2026, 8, 19),
      customerPhone: '9876543210',
    );
    final retry = SupabaseOwnerBookingRepository.offlineIdempotencyKey(
      venueId: 'venue-1',
      slotId: 'slot-1',
      bookDate: DateTime(2026, 8, 19, 18, 30),
      customerPhone: ' 9876543210 ',
    );
    expect(first, retry);
    expect(first, isNotEmpty);
  });

  test('different offline booking requests do not share a retry key', () {
    final first = SupabaseOwnerBookingRepository.offlineIdempotencyKey(
      venueId: 'venue-1',
      slotId: 'slot-1',
      bookDate: DateTime(2026, 8, 19),
      customerPhone: '9876543210',
    );
    final otherSlot = SupabaseOwnerBookingRepository.offlineIdempotencyKey(
      venueId: 'venue-1',
      slotId: 'slot-2',
      bookDate: DateTime(2026, 8, 19),
      customerPhone: '9876543210',
    );
    expect(first, isNot(otherSlot));
  });
}
