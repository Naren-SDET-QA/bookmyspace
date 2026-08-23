import 'package:bookmyspace/features/payments/domain/payment_health.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment health summary never infers capture from missing data', () {
    final summary = PaymentHealthSummary.fromJson({
      'payments': {'pending': 2, 'captured': 5, 'failed': 1},
      'refunds': {'requested': 1},
      'active_holds': 3,
    });
    expect(summary.pending, 2);
    expect(summary.captured, 5);
    expect(summary.failed, 1);
    expect(summary.activeHolds, 3);
    expect(PaymentHealthSummary.fromJson({}).captured, 0);
  });

  test('unified registration modules match Android zip targets', () {
    expect(
      unifiedRegistrationModules.map((m) => m.key),
      ['customer', 'venue_owner', 'institute_student', 'event_attendee'],
    );
  });

  test('listing field metadata round-trips without category switches', () {
    const config = CategoryConfiguration(
      id: '1',
      slug: 'marriage_hall',
      name: 'Marriage Hall',
      sectionId: 'function_halls',
      requiredFields: ['event_type', 'guest_count'],
      optionalFields: ['catering'],
    );
    final json = config.toMetadata();
    expect(json['required_fields'], ['event_type', 'guest_count']);
    expect(json['booking_mode'], 'instant');
    expect(
      config.copyWith(requiredFields: ['capacity']).requiredFields,
      ['capacity'],
    );
  });
}
