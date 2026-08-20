import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/config/settings_controller.dart';

void main() {
  test('booking modes expose normal and quick options', () {
    expect(
      BookingMode.values,
      containsAll([BookingMode.normal, BookingMode.quick]),
    );
  });
}
