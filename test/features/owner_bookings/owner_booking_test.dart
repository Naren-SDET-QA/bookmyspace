import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OwnerBookingAction', () {
    test('maps actions to their wire values', () {
      expect(OwnerBookingAction.confirm.dbValue, 'confirm');
      expect(OwnerBookingAction.complete.dbValue, 'complete');
      expect(OwnerBookingAction.cancel.dbValue, 'cancel');
      expect(OwnerBookingAction.noShow.dbValue, 'no_show');
    });
  });
}