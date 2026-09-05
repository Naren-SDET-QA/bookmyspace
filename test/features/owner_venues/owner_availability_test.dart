import 'package:bookmyspace/features/owner_venues/domain/owner_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner time slot validation rejects invalid ranges', () {
    expect(
      () => OwnerTimeSlot.validate(
        label: 'Bad',
        startTime: '10:00',
        endTime: '09:00',
        priceAmount: 1,
      ),
      throwsStateError,
    );
    expect(
      () => OwnerTimeSlot.validate(
        label: 'Good',
        startTime: '09:00',
        endTime: '10:00',
        priceAmount: 1,
      ),
      returnsNormally,
    );
  });
}
