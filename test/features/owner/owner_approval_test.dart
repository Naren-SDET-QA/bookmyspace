import 'package:bookmyspace/features/owner/presentation/widgets/owner_booking_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approval countdown is readable and expires safely', () {
    final now = DateTime(2026, 8, 4, 10);
    expect(
      approvalCountdown(now.add(const Duration(hours: 2, minutes: 5)), now),
      '2h 5m',
    );
    expect(
      approvalCountdown(now.add(const Duration(seconds: 59)), now),
      '0m 59s',
    );
    expect(
      approvalCountdown(now.subtract(const Duration(seconds: 1)), now),
      'Expired',
    );
  });
}
