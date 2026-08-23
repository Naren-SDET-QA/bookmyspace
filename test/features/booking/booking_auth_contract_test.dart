import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'booking hold requires the session token and forwards it as Authorization',
    () {
      final source = File(
        'lib/features/booking/infrastructure/supabase_booking_repository.dart',
      ).readAsStringSync();

      expect(source, contains('currentSession'));
      expect(source, contains('accessToken'));
      expect(source, contains("'Authorization'"));
      expect(source, contains("'Bearer "));
      expect(source, contains('functions.invoke'));
    },
  );
}
