import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant screen invokes clarification before action gate', () {
    final source = File(
      'lib/features/ai/presentation/screens/assistant_screen.dart',
    ).readAsStringSync();
    expect(source, contains("'ai-clarification'"));
    expect(source, contains("'ai-action-gate'"));
    expect(source, contains('.invoke('));
    expect(source, contains("'BOOKING_PREVIEW'"));
    expect(source, contains("'BOOKING_HANDOFF'"));
    expect(source, contains('venueRepositoryProvider'));
    expect(source, contains('AppRoutes.bookingFlow'));
    expect(source, isNot(contains('bookingRepositoryProvider')));
    expect(source, isNot(contains("'CONFIRM_BOOKING'")));
    expect(source, contains('DynamicClarificationForm'));
  });
}
