import 'package:bookmyspace/features/checkin/domain/check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check-in result never invents success from missing flags', () {
    final result = CheckInResult.fromJson({
      'ok': true,
      'already_checked_in': true,
      'booking_id': 'b1',
      'check_in_id': 'c1',
    });
    expect(result.ok, isTrue);
    expect(result.alreadyCheckedIn, isTrue);
    expect(result.bookingId, 'b1');
  });

  test('missing ok is treated as failure', () {
    final result = CheckInResult.fromJson({'booking_id': 'b1'});
    expect(result.ok, isFalse);
  });
}
